(ns k3s-fleetops.core
  (:require
   [babashka.fs :as fs]
   [babashka.process :refer [process shell]]
   [cli-matic.core :as cli]
   [cli-matic.utils-v2 :as U2]
   [clojure.edn :as edn]
   [clojure.string :as str]))

(def dry-run
  {:option  "dry-run"
   :env     "DRY_RUN"
   :as      "Dry Run?"
   :type    :with-flag
   :default false})

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

(defn build-yaml
  [opts]
  (let [dry-run?        (:dry-run opts)
        cwd             (fs/cwd)
        output-dir      "target"
        output-path     (fs/path cwd output-dir)
        relative-output (fs/relativize cwd output-path)
        yaml-files (->> (fs/glob "." "**/*.yaml")
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
          (fs/copy file-path target-directory {:replace-existing true}))))))

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(defn build
  [& [opts]]
  (println opts)
  (let [dry-run?    (:dry-run opts)
        verbose?    (:verbose opts)
        cwd         (fs/cwd)
        output-dir  "target"
        output-path (fs/path cwd output-dir)]
    (if dry-run?
      (println (str "[DRY-RUN] create directories: " output-path))
      (fs/create-dirs output-path))
    (let [files (->> (fs/glob "." "**/*.edn")
                     (filter (fn [f] (not (.endsWith f "bb.edn"))))
                     (into []))]
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
              (println (str "[DRY-RUN] create directories: " target-directory))
              (fs/create-dirs target-directory)))
          (let [target-path-string (fs/relativize cwd target-path)
                parts              [(str "cat " absolute)
                                    (str "jet -i edn -o yaml")
                                    (str (if verbose? "tee " "dd of=") target-path-string)]
                command            (str "sh -c \"" (str/join " | " parts) "\"")]
            (if dry-run?
              (println (str "[DRY-RUN] " command))
              (shell command))))))
    (build-yaml opts)))

(defn prompt-password
  []
  (let [prompt-cmd "gum input --password --prompt 'Enter Keepass Password> '"
        response   (shell {:out :string} prompt-cmd)]
    (if (zero? (:exit response))
      (:out response)
      (throw (ex-info "Failed to prompt password" {})))))

(defn choose
  [options]
  (let [cmd (str "gum choose " (str/join " " options))]
    (:out (shell {:out :string} cmd))))

(def sealed-secrets-controller {:name "sealed-secrets" :ns "sealed-secrets"})

(defn read-password
  ([keepass-password key-path]
   (let [field "Password"]
     (read-password keepass-password key-path field)))
  ([keepass-password key-path field]
   (read-password keepass-password key-path field (env+ "KEEPASS_DB_PATH")))
  ([keepass-password key-path field db-path]
   (let [cmd      (str "keepassxc-cli show -s -a " field  " " db-path " " key-path)
         response @(process {:in keepass-password :out :string} cmd)]
     (if (zero? (:exit response))
       (->> response :out str/trim-newline)
       (throw (ex-info "Failed to read password" {:type :password-read-error}))))))

(defn create-secret
  ([chosen-data secret-values]
   (let [extra-args []]
     (create-secret chosen-data secret-values extra-args)))
  ([{target-ns :ns :keys [secret-name]} secret-values extra-args]
   (let [args (concat ["kubectl create secret generic"
                       secret-name
                       (str "--namespace " target-ns)
                       "--dry-run=client"
                       "--from-env-file=/dev/stdin"
                       "-o json"]
                      extra-args)
         cmd (str/join " " args)]
     #_(binding [*out* *err*] (println cmd))
     (:out (shell {:in secret-values :out :string} cmd)))))

(defn seal-secret
  [{target-ns :ns :keys [secret-name]} secret-json]
  (let [sealed-dir      (str "argo-application-manifests/" target-ns "/")
        sealed-file     (str sealed-dir secret-name "-sealed-secret.yaml")
        controller-name (:name sealed-secrets-controller)
        controller-ns   (:ns sealed-secrets-controller)
        args            ["kubeseal"
                         (str "--namespace " target-ns)
                         (str "--controller-name " controller-name)
                         (str "--controller-namespace " controller-ns)
                         "--secret-file /dev/stdin"
                         (str "--sealed-secret-file " sealed-file)]
        cmd             (str/join " " args)]
    #_(binding [*out* *err*] (println cmd))
    (fs/create-dirs sealed-dir)
    (shell {:in secret-json} cmd)))

(defn get-secret-data
  []
  (edn/read-string (slurp "secrets.edn")))

(defn get-secret-values
  [{:keys [fields]} keepass-password]
  (->> (for [[k {:keys [literal path field]
                 :or   {field "Password"}
                 :as   data}] fields]
         (let [data (cond
                      (seq literal) literal
                      (seq path)    (read-password keepass-password path field)
                      :else         (throw (ex-info "Missing key" {:data data})))]
           (str k "=" data)))
       (str/join "\n")))

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(defn create-sealed-secret
  ([]
   (let [secret-data  (get-secret-data)
         secret-names (->> secret-data keys (map name))
         secret-key   (keyword (choose secret-names))
         chosen-maps  (get secret-data secret-key)]
     (create-sealed-secret secret-key chosen-maps)))
  ([secret-key]
   (let [secret-data (get-secret-data)
         chosen-maps (get secret-data secret-key)]
     (create-sealed-secret secret-key chosen-maps)))
  ([secret-key chosen-maps]
   (let [keepass-password (prompt-password)]
     (create-sealed-secret secret-key chosen-maps keepass-password)))
  ([_secret-key chosen-maps keepass-password]
   (doseq [chosen-data chosen-maps]
     (let [secret-values (get-secret-values chosen-data keepass-password)
           secret-json   (create-secret chosen-data secret-values [])]
       (seal-secret chosen-data secret-json)))))

(defn create-sealed-secret-command
  [{:keys [keepass-password secret-name]}]
  (try
    (let [secret-data      (get-secret-data)
          secret-names     (->> secret-data keys (map name))
          secret-name      (or secret-name (choose secret-names))
          keepass-password (or keepass-password (prompt-password))
          secret-key       (keyword secret-name)
          chosen-maps      (get secret-data secret-key)]
      (println {:secret-key secret-key :keepass-password keepass-password :chosen-maps chosen-maps})
      (create-sealed-secret secret-key chosen-maps keepass-password))
    (catch Exception ex
      (binding [*out* *err*] (println (ex-message ex)))
      #_(binding [*out* *err*] (println ex))
      (System/exit 1))))

(defn list-secrets-command
  [_opts]
  #_(println opts)
  (let [secret-data      (get-secret-data)
        secret-names     (->> secret-data keys (map name))]
    (->> secret-names (str/join "\n") println)))

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(defn k3d-create
  [& [opts]]
  (println opts)
  (let [dry-run?         true
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

(declare CONFIGURATION)

(defn zsh-completion
  []
  (let [app-name "kops"
        args [(str "#compdef " app-name)
              (str "compdef _" app-name " " app-name)
              ""
              (str "# zsh completion for " app-name " -*- shell-script -*-")
              ""
              (str "__" app-name "_debug()")
              "{"
              "  local file=\"$BASH_COMP_DEBUG_FILE\""
              "  if [[ -n ${file} ]]; then"
              "    echo \" $* \" >> \" $ {file} \""
              "  fi"
              "}"
              ""
              (str "_" app-name "()")
              "{"
              "  local shellCompDirectiveError=1"
              "  local shellCompDirectiveNoSpace=2"
              "  local shellCompDirectiveNoFileComp=4"
              "  local shellCompDirectiveFilterFileExt=8"
              "  local shellCompDirectiveFilterDirs=16"
              "  local shellCompDirectiveKeepOrder=32"
              ""
              "  local lastParam lastChar flagPrefix requestComp out directive comp lastComp noSpace keepOrder"
              "  local -a completions"
              (str "  __" app-name "_debug \"\\n========= starting completion logic ==========\"")
              (str "  __" app-name "_debug \"CURRENT: ${CURRENT}, words[*]: ${words[*]}\"")
              (str "  local matches=(`" app-name " tasks | sed -r 's/\\t/:/g'`)")
              #_(str "  local matches=(`" app-name " tasks | cut -f1`)")
              #_(str "  compadd -a matches")
              (str "_describe 'command' matches")
              "}"
              ""
              (str "compdef _" app-name " " app-name)]
        script (str/join "\n" args)]
    (println script)))

(defn completion-command
  [& [args]]
  ;; (println args)
  ;; (prn CONFIGURATION)
  (let [shell (first (:_arguments args))]
    ;; (println "shell " shell)
    (case shell
      "zsh"    (zsh-completion)
      :default (throw (ex-info "Unknown shell type" {:shell shell})))))

(defn find-command
  [config subcommand-path]
  (reduce
   (fn [m cn]
     (first (filter
             (fn [co]
               (= cn (:command co)))
             (:subcommands m))))
   config
   (rest subcommand-path)))

(defn complete
  [args config-obj]
  (let [config (U2/cfg-v2 config-obj)]
    (println config)
    (let [args (if (nil? args) [] args)]
      (println "args" args)
      (let [{:keys [parse-errors subcommand-path]
             :as parsed} (cli/parse-command-line args config)
            command-config (find-command config subcommand-path)]
        (if (= parse-errors :ERR-NO-SUBCMD)
          (println (str/join "\n" (map :command (:subcommands command-config))))
          (if (= parse-errors :ERR-UNKNOWN-SUBCMD)
            (do
              (println "parsed" parsed)
              (println "command-config" command-config)
              (let [other-paths (drop-last subcommand-path)
                    final-stub (last subcommand-path)]
                (if (not= final-stub (last args))
                  (do
                    ;; This path doesn't match a command, but the non-matching command isn't the last token
                    (println "not final token")
                    [])
                  (do
                    (println "other-paths" other-paths)
                    (let [prev-command (find-command config other-paths)]
                      (println "prev-command" prev-command)
                      (let [matched-commands (filter
                                              (fn [command]
                                                (str/starts-with? (:command command) final-stub))
                                              (:subcommands prev-command))]
                        (println "matched commands" (map :command matched-commands))))))))
            (do
              (println "parsed" parsed)
              (println "command-config" command-config)
              (println (str/join "\n" (map #(str "--" %) (map :option (:opts command-config))))))))))))

(defn display-tasks
  [& [_args]]
  (println
   (str/join "\n"
             (map
     (fn [command-obj]
       (str (:command command-obj) "\t" (:description command-obj)))
     (:commands CONFIGURATION)))))

(def CONFIGURATION
  {:app
   {:command     "kops"
    :description "A tool for managing clusters"
    :version     "0.0.1"}
   :global-opts []
   :commands
   [{:command     "build" :short "b"
     :description "Build the app"
     :opts
     [dry-run
      {:option  "verbose"
       :short   "v"
       :type    :with-flag
       :default false}]
     :runs        build}
    {:command     "cluster"
     :short       "c"
     :description "Manages clusters"
     :subcommands
     [{:command     "create"
       :short       "c"
       :description "Creates a cluster"
       :opts
       [dry-run
        {:option  "ingress"
         :env     "USE_INGRESS"
         :type    :with-flag
         :default false}
        {:option  "api-port"
         :env     "API_PORT"
         :type    :int
         :default 6550}
        {:option  "registry"
         :env     "USE_REGISTRY"
         :type    :with-flag
         :default true}
        {:option  "registry-name"
         :env     "REGISTRY_NAME"
         :type    :string
         :default "registry"}
        {:option  "registry-host"
         :env     "REGISTRY_HOST"
         :short   "h"
         :type    :string
         :default "k3d-myregistry.localtest.me:12345"}
        {:option  "create-registry"
         :env     "REGISTRY_CREATE"
         :type    :with-flag
         :default false}]
       :runs        k3d-create}]}
    {:command     "completion"
     :description "Completion script"
     :runs        completion-command}
    {:command     "secrets"
     :short       "s"
     :description "Manages secrets"
     :subcommands
     [{:command     "create"
       :short       "c"
       :description "Seals a secret"
       :opts
       [{:option "keepass-password"
         :short  "p"
         :env    "KEEPASS_PASSWORD"
         :type   :string
         :as     "Keepass Password"}
        {:option "secret-name"
         :short  "n"
         :as     "Secret Name"
         :env    "SECRET_NAME"
         :type   :string}]
       :runs        create-sealed-secret-command}
      {:command     "list"
       :short       "l"
       :description "Lists the configured secrets"
       :runs        list-secrets-command}]}
    {:command "tasks"
     :descriptions "Display tasks"
     :runs display-tasks}]})
