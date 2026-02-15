(ns k3s-fleetops.postgres
  (:require
   [babashka.fs :as fs]
   [babashka.process :refer [shell]]
   [cheshire.core :as json]
   [clj-yaml.core :as yaml]
   [clojure.string :as str]))

(def pg-namespace "postgresql")
(def secret-name "postgresql-password")
(def admin-user "postgres")
(def port "5432")

(defn get-pod-name
  "Get the PostgreSQL pod name from the cluster"
  []
  (str/trim (:out (shell {:out :string}
                         (str "kubectl get pods -n " pg-namespace
                              " -l app.kubernetes.io/name=postgres"
                              " -o jsonpath='{.items[0].metadata.name}'")))))

(defn get-admin-password
  "Get the admin password from Kubernetes secret"
  []
  (str/trim (:out (shell {:out :string}
                         (str "sh -c \"kubectl get secret " secret-name
                              " -n " pg-namespace
                              " -o jsonpath='{.data.adminPassword}'"
                              " | base64 -d\"")))))

(defn exec-psql
  "Execute a psql command in the PostgreSQL pod"
  [pod-name password command]
  (shell (str "sh -c \"kubectl exec -n " pg-namespace " " pod-name " --"
              " env PGPASSWORD='" password "'"
              " psql -h localhost -U " admin-user
              " -p " port " -c '" command "' postgres\"")))

(defn exec-psql-json
  "Execute a psql command and return JSON output"
  [pod-name password query]
  (let [result (:out (shell {:out :string}
                            (str "sh -c \"kubectl exec -n " pg-namespace " " pod-name " --"
                                 " env PGPASSWORD='" password "'"
                                 " psql -h localhost -U " admin-user
                                 " -p " port " -t -A -F',' -c '" query "' postgres\"")))]
    (str/split-lines result)))

(defn parse-db-size-row
  "Parse a database size row from psql output"
  [line]
  (when (seq line)
    (let [parts (str/split line #"," 2)]
      (when (= (count parts) 2)
        {:name (str/trim (first parts))
         :size (str/trim (second parts))}))))


(defn get-all-database-names
  "Return a list of all database names (excluding templates). Requires pod-name and password."
  [pod-name password]
  (let [query "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;"
        result (:out (shell {:out :string}
                            (str "sh -c \"kubectl exec -n " pg-namespace " " pod-name " --"
                                 " env PGPASSWORD='" password "'"
                                 " psql -h localhost -U " admin-user
                                 " -p " port " -t -A -c '" query "' postgres\"")))]
    (->> (str/split-lines result)
         (map str/trim)
         (filter seq))))

(defn list-databases
  "List all PostgreSQL databases. If json? is true, output JSON format"
  ([]
   (list-databases false))
  ([json?]
  (let [pod-name (get-pod-name)]
    (when (empty? pod-name)
      (println "Error: Could not find PostgreSQL pod in pg-namespace" pg-namespace)
      (System/exit 1))
    (let [password (get-admin-password)]
      (if json?
        (let [size-rows (exec-psql-json pod-name
                                         password
                                         "SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;")
              databases (->> size-rows
                            (map parse-db-size-row)
                            (filter some?)
                            (map (fn [db]
                                   {:name (:name db)
                                    :size (:size db)
                                    :size_bytes (let [size-str (:size db)]
                                                  (when-let [match (re-find #"(\d+(?:\.\d+)?)\s*(\w+)" size-str)]
                                                    (let [value (Double/parseDouble (first (rest match)))
                                                          unit (second (rest match))]
                                                      (case unit
                                                        "bytes" value
                                                        "kB" (* value 1024)
                                                        "MB" (* value 1024 1024)
                                                        "GB" (* value 1024 1024 1024)
                                                        "TB" (* value 1024 1024 1024 1024)
                                                        value))))})))]
          (println (json/generate-string {:namespace pg-namespace
                                         :pod pod-name
                                         :databases (vec databases)}
                                        {:pretty true})))
        (do
          (println "=== PostgreSQL Database List ===")
          (println "Namespace:" pg-namespace)
          (println "Pod:" pod-name)
          (println "")
          (println "Databases:")
          (exec-psql pod-name password "\\l")
          (println "")
          (println "=== Database Sizes ===")
          (exec-psql pod-name
                      password
                      "SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC;")))))))

(defn backup-database
  "Backup a single database"
  [pod-name password db-name output-dir timestamp]
  (let [sql-file (str output-dir "/" db-name "_" timestamp ".sql")
        custom-file (str output-dir "/" db-name "_" timestamp ".custom")]
    (println "Backing up database:" db-name)
    ;; Create SQL dump
    (shell (str "sh -c \"kubectl exec -n " pg-namespace " " pod-name " --"
                " env PGPASSWORD='" password "'"
                " pg_dump -h localhost -U " admin-user
                " -p " port
                " --clean --if-exists --create --format=plain"
                " --no-owner --no-privileges " db-name
                " > " sql-file "\""))
    ;; Create custom format dump
    (shell (str "sh -c \"kubectl exec -n " pg-namespace " " pod-name " --"
                " env PGPASSWORD='" password "'"
                " pg_dump -h localhost -U " admin-user
                " -p " port
                " --clean --if-exists --create --format=custom"
                " --no-owner --no-privileges " db-name
                " > " custom-file "\""))
    ;; Compress SQL file
    (shell (str "gzip -f " sql-file))
    (println "✓ Backup completed:" (str sql-file ".gz"))
    (println "✓ Backup completed:" custom-file)
    (println "")))

(defn backup-databases
  "Backup PostgreSQL databases"
  [target-db output-dir]
  (let [pod-name (get-pod-name)]
    (when (empty? pod-name)
      (println "Error: Could not find PostgreSQL pod in pg-namespace" pg-namespace)
      (System/exit 1))
    (let [password (get-admin-password)
          timestamp (str/replace (str/replace (str (java.util.Date.)) " " "_") ":" "")
          dbs-to-backup (if target-db
                          [target-db]
                          (get-all-database-names pod-name password))]
      (fs/create-dirs output-dir)
      (println "=== PostgreSQL Backup Script ===")
      (println "Namespace:" pg-namespace)
      (println "Output directory:" output-dir)
      (println "Timestamp:" timestamp)
      (println "")
      (doseq [db-name dbs-to-backup]
        (backup-database pod-name password db-name output-dir timestamp))
      (println "=== Backup Complete ===")
      (println "Backups saved to:" output-dir)
      (try
        (shell (str "sh -c \"ls -lh " output-dir "/*" timestamp "* 2>/dev/null || true\""))
        (catch Exception _e
          ;; Ignore errors from ls if no files match
          nil)))))

(defn extract-db-name-from-filename
  "Extract database name from backup filename"
  [filename]
  (when-let [match (re-find (re-pattern "^([^_]+)_\\d{8}_\\d{6}") filename)]
    (second match)))

(defn drop-database
  "Drop a database if it exists"
  [pod-name password db-name]
  (println "Dropping existing database (if exists)...")
  (exec-psql pod-name password (str "DROP DATABASE IF EXISTS \"" db-name "\";"))
  (println ""))

(defn restore-custom-format
  "Restore from custom format dump"
  [pod-name password backup-file]
  (println "Restoring from custom format dump...")
  (shell (str "kubectl cp " backup-file " " pg-namespace "/" pod-name ":/tmp/restore_backup.custom"))
  (shell (str "sh -c \"kubectl exec -n " pg-namespace " " pod-name " --"
              " env PGPASSWORD='" password "'"
              " pg_restore -h localhost -U " admin-user
              " -p " port
              " --clean --if-exists --create --no-owner --no-privileges"
              " -d postgres /tmp/restore_backup.custom\""))
  (shell (str "kubectl exec -n " pg-namespace " " pod-name " -- rm -f /tmp/restore_backup.custom")))

(defn restore-sql-format
  "Restore from SQL format dump"
  [pod-name password backup-file]
  (println "Restoring from SQL dump...")
  (let [temp-sql (when (str/ends-with? backup-file ".sql.gz")
                   (let [temp (fs/create-temp-file {:prefix "postgres-restore-" :suffix ".sql"})]
                     (shell (str "sh -c \"gunzip -c " backup-file " > " temp "\""))
                     temp))
        sql-file (or temp-sql backup-file)]
    (shell (str "kubectl cp " sql-file " " pg-namespace "/" pod-name ":/tmp/restore_backup.sql"))
    (shell (str "sh -c \"kubectl exec -n " pg-namespace " " pod-name " --"
                " env PGPASSWORD='" password "'"
                " psql -h localhost -U " admin-user
                " -p " port
                " -f /tmp/restore_backup.sql postgres\""))
    (shell (str "kubectl exec -n " pg-namespace " " pod-name " -- rm -f /tmp/restore_backup.sql"))
    (when temp-sql (fs/delete temp-sql))))

(defn restore-from-pvc
  "Restore full cluster from a backup file on the postgresql-backups PVC (pg_dumpall format).
   backup-filename should be e.g. postgresql-backup-20250215_020000.sql.gz"
  [backup-filename]
  (let [job-name   (str "postgresql-restore-" (System/currentTimeMillis))
        restore-cmd (str "set -e\n"
                         "echo \"Restoring from /backups/" backup-filename "\"\n"
                         "gunzip -c /backups/" backup-filename " | PGPASSWORD=\"$PGPASSWORD\" psql -h postgresql." pg-namespace " -U " admin-user " -d postgres\n"
                         "echo \"Restore completed successfully.\"")
        pod-spec   {"restartPolicy" "Never"
                    "containers"   [{"name"    "restore"
                                     "image"   "pgvector/pgvector:pg17"
                                     "command" ["/bin/bash" "-c" restore-cmd]
                                     "env"     [{"name" "PGPASSWORD"
                                                "valueFrom" {"secretKeyRef" {"name" secret-name
                                                                             "key"  "adminPassword"}}}]
                                     "volumeMounts" [{"name" "backups" "mountPath" "/backups"}]}]
                    "volumes"     [{"name" "backups"
                                    "persistentVolumeClaim" {"claimName" "postgresql-backups"}}]}
        job-spec   {"apiVersion" "batch/v1"
                    "kind"       "Job"
                    "metadata"   {"name" job-name "namespace" pg-namespace}
                    "spec"       {"ttlSecondsAfterFinished" 300
                                  "template" {"spec" pod-spec}}}
        job-yaml   (yaml/generate-string job-spec)]
    (println "=== PostgreSQL Restore from PVC ===")
    (println "Backup file on PVC:" backup-filename)
    (println "Creating restore Job:" job-name)
    (shell {:in job-yaml} "kubectl apply -f -")
    (println "Monitor progress: kubectl logs -n " pg-namespace " -f job/" job-name)
    (println "Waiting for Job to complete...")
    (shell (str "kubectl wait --for=condition=complete job/" job-name " -n " pg-namespace " --timeout=600s"))
    (println "=== Restore Complete ===")
    (println "Full cluster restored from:" backup-filename)))

(defn restore-database
  "Restore PostgreSQL database from backup.
   If backup-file is a path to a local file, restores from that file.
   If backup-file is a filename only (no /) and not found locally, restores from the postgresql-backups PVC."
  [backup-file target-db recreate?]
  (when (or (nil? backup-file) (empty? backup-file))
    (println "Error: BACKUP_FILE environment variable is required")
    (println "Usage: BACKUP_FILE=path/to/backup.sql.gz or BACKUP_FILE=postgresql-backup-YYYYMMDD_HHMMSS.sql.gz")
    (println "       [DATABASE=dbname] [RECREATE=true] bb postgres-restore")
    (System/exit 1))
  ;; Restore from PVC when file does not exist locally and looks like a backup filename (no path)
  (if (and (not (fs/exists? backup-file))
           (not (str/includes? backup-file "/"))
           (or (str/ends-with? backup-file ".sql.gz") (str/ends-with? backup-file ".sql")))
    (restore-from-pvc backup-file)
    (let [pod-name (get-pod-name)]
      (when (empty? pod-name)
        (println "Error: Could not find PostgreSQL pod in pg-namespace" pg-namespace)
        (System/exit 1))
      (when-not (fs/exists? backup-file)
        (println "Error: Backup file not found:" backup-file)
        (System/exit 1))
      (let [backup-basename (fs/file-name backup-file)
            db-name (or target-db (extract-db-name-from-filename backup-basename))
            password (get-admin-password)]
        (when (nil? db-name)
          (println "Error: Could not determine database name from filename:" backup-basename)
          (println "Please specify DATABASE environment variable")
          (System/exit 1))
        (println "=== PostgreSQL Restore Script ===")
        (println "Namespace:" pg-namespace)
        (println "Backup file:" backup-file)
        (println "Target database:" db-name)
        (println "")
        (when recreate?
          (drop-database pod-name password db-name))
        (cond
          (str/ends-with? backup-file ".custom")
          (restore-custom-format pod-name password backup-file)
          (or (str/ends-with? backup-file ".sql.gz") (str/ends-with? backup-file ".sql"))
          (restore-sql-format pod-name password backup-file)
          :else
          (do
            (println "Error: Unsupported backup file format. Expected .sql, .sql.gz, or .custom")
            (System/exit 1)))
        (println "")
        (println "=== Restore Complete ===")
        (println "Database '" db-name "' has been restored from:" backup-file)
        (println "")
        (println "Verifying database...")
        (exec-psql pod-name password "\\l")))))

