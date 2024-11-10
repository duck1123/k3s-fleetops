(ns k3s-fleetops.core
  (:require
   [babashka.fs :as fs]
   [babashka.tasks :refer [shell]]
   [clojure.string :as str]))

(defn env
  ([key]
   (System/getenv key))
  ([key default]
   (or (env key) default)))

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(defn env+
  [key]
  (or (env key) (throw (ex-info "Missing key" {:key key}))))

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(defn earthly
  ([target]
   (earthly target {}))
  ([target opts]
   (println opts)
   (let [flags   (->> [(when (:interactive opts) "-i")
                       (when (:privileged opts) "-P")]
                      (filter identity)
                      (str/join " "))
         secrets (if-let [secret-names (:secrets opts)]
                   (->> secret-names
                        (map (fn [n] (str "--secret " n)))
                        (str/join " "))
                   "")
         args    (if-let [arg-map (:args opts)]
                   (let [ks (keys arg-map)]
                     (->> ks
                          (map (fn [k] (str "--" k "=" (get arg-map k))))
                          (str/join " ")))

                   "")
         parts ["earthly"
                flags
                secrets
                target
                args]
         cmd   (str/join " " parts)]
     #_(println cmd)
     (shell cmd))))

(defn build
  []
  (let [dry-run?        false
        verbose?        false
        cwd             (fs/cwd)
        output-dir      "target"
        output-path     (fs/path cwd output-dir)
        relative-output (fs/relativize cwd output-path)
        files           (->> (fs/glob "." "**/*.edn")
                             (filter (fn [f] (not (.endsWith f "bb.edn"))))
                             (into []))]
    (let [command (str "mkdir -p " output-path)]
      (if dry-run?
        (println (str "[DRY-RUN] " command))
        (shell command)))
    (doseq [file files]
      (when verbose?
        (println (str "# File: " file "\n----")))
      (let [file-path             (fs/absolutize (fs/path file))
            input-parent          (fs/parent file)
            absolute-input-parent (fs/absolutize input-parent)
            relative-input-dir    (fs/relativize cwd absolute-input-parent)
            absolute              (fs/relativize cwd file-path)
            base-path             (fs/relativize absolute-input-parent file-path)
            base-name             (fs/strip-ext base-path)
            target-directory      (fs/path output-path relative-input-dir)
            target-path           (fs/path target-directory (str base-name ".yaml"))]
        (when-not (fs/exists? target-directory)
          (if dry-run?
            (println (str "[DRY-RUN] sh -c \"mkdir -p " target-directory "\""))
            (fs/create-dirs target-directory)))
        (let [target-path-string (fs/relativize cwd target-path)
              parts              [(str "cat " absolute)
                                  (str "jet -i edn -o yaml")
                                  (str (if verbose? "tee " "dd of=") target-path-string)]
              command            (str "sh -c \"" (str/join " | " parts) "\"")]
          (if dry-run?
            (println (str "[DRY-RUN] " command))
            (shell command)))))
    (let [yaml-files (->> (fs/glob "." "**/*.yaml")
                          (filter (fn [f]
                                    (not (or
                                          (fs/starts-with? f relative-output)
                                          (fs/starts-with? f "fleet")))))
                          (into []))]
      (doseq [file yaml-files]
        (let [file-path             (fs/absolutize (fs/path file))
              input-parent          (fs/parent file)
              absolute-input-parent (fs/absolutize input-parent)
              relative-input-dir    (fs/relativize cwd absolute-input-parent)
              target-directory      (fs/path output-path relative-input-dir)]
          (when-not (fs/exists? target-directory)
            (if dry-run?
              (println (str "[DRY-RUN] sh -c \"mkdir -p " target-directory "\""))
              (fs/create-dirs target-directory)))
          (if dry-run?
            (println (str "copy" file-path " - " target-directory))
            (fs/copy file-path target-directory {:replace-existing true})))))))

(defn prompt-password
  []
  (let [prompt-cmd "gum input --password --prompt 'Enter Keepass Password> '"]
    (:out (shell {:out :string} prompt-cmd))))

(defn read-password
  ([keepass-password key-path]
   (read-password keepass-password key-path (env+ "KEEPASS_DB_PATH")))
  ([keepass-password key-path db-path]
   (->> (str "keepassxc-cli show -s -a Password " db-path " " key-path)
        (shell {:in keepass-password :out :string})
        :out
        str/trim-newline)))

(defn create-secret
  ([secret-name target-ns key-name secret-data]
   (create-secret secret-name target-ns key-name secret-data []))
  ([secret-name target-ns key-name secret-data extra-args]
   (let [args (concat ["kubectl create secret generic"
                       secret-name
                       (str "--namespace " target-ns)
                       "--dry-run=client"
                       (str "--from-file=" key-name "=/dev/stdin")
                       "-o json"]
                      extra-args)
         cmd (str/join " " args)]
     #_(println cmd)
     (:out (shell {:in secret-data :out :string} cmd)))))

(defn seal-secret
  [controller-ns controller-name target-ns sealed-file secret-json]
  (let [args ["kubeseal"
              (str "--namespace " target-ns)
              (str "--controller-name " controller-name)
              (str "--controller-namespace " controller-ns)
              "--secret-file /dev/stdin"
              (str "--sealed-secret-file " sealed-file)]
        cmd  (str/join " " args)]
    #_(println cmd)
    (shell {:in secret-json} cmd)))

(defn create-forgejo-password-secret
  []
  (let [target-ns        "forgejo"
        key-name         "password"
        key-path         "/Kubernetes/Forgejo"
        secret-name      "forgejo-admin-password"
        controller-name  "sealed-secrets"
        controller-ns    "sealed-secrets"
        sealed-dir       "argo-application-manifests/forgejo/"
        sealed-file      (str sealed-dir "forgejo-admin-password-sealed-secret.yaml")
        keepass-password (prompt-password)
        password         (read-password keepass-password key-path)
        extra-args       ["--from-literal=username=admin"]
        secret-data      (create-secret secret-name target-ns key-name password extra-args)]
    (shell (str "mkdir -p " sealed-dir))
    (seal-secret controller-ns controller-name target-ns sealed-file secret-data)))

(defn create-harbor-password-secret
  []
  (let [target-ns        "harbor"
        key-name         "HARBOR_ADMIN_PASSWORD"
        key-path         "/Kubernetes/Harbor"
        secret-name      "harbor-admin-password"
        controller-name  "sealed-secrets"
        controller-ns    "sealed-secrets"
        sealed-dir       "argo-application-manifests/harbor/"
        sealed-file      (str sealed-dir "harbor-admin-password-sealed-secret.yaml")
        keepass-password (prompt-password)]
    (shell (str "mkdir -p " sealed-dir))
    (->> (read-password keepass-password key-path)
         (create-secret secret-name target-ns key-name)
         (seal-secret controller-ns controller-name target-ns sealed-file))))

(defn create-keycloak-password-secret
  []
  (let [target-ns        "keycloak"
        key-name         "KEYCLOAK_ADMIN_PASSWORD"
        key-path         "/Kubernetes/Keycloak"
        secret-name      "keycloak-admin-password"
        controller-name  "sealed-secrets"
        controller-ns    "sealed-secrets"
        sealed-dir       "argo-application-manifests/keycloak/"
        sealed-file      (str sealed-dir "keycloak-admin-password-sealed-secret.yaml")
        keepass-password (prompt-password)]
    (shell (str "mkdir -p " sealed-dir))
    (->> (read-password keepass-password key-path)
         (create-secret secret-name target-ns key-name)
         (seal-secret controller-ns controller-name target-ns sealed-file))))

(defn k3d-create
  []
  (let [dry-run?         false
        use-ingress      false
        create-registry? false
        use-registry?    false
        api-port         6550
        registry-name    "registry"
        registry-host    "k3d-myregistry.localtest.me:12345"
        server-count     1
        args             ["k3d cluster create"
                          "--api-port" api-port
                          "-p \"80:80@loadbalancer\""
                          "-p \"443:443@loadbalancer\""
                          (when-not use-ingress "--k3s-arg \"--disable=traefik@server:0\"")
                          "--servers" server-count
                          "--volume kube-nfs-volume:/opt/local-path-provisioner"
                          (when create-registry?
                            (str "--registry-create " registry-name))
                          (when use-registry?
                            (str "--registry-use " registry-host))
                          "--kubeconfig-update-default"]
        cmd              (str/join " " args)]
    (if dry-run?
      (println cmd)
      (shell cmd))))
