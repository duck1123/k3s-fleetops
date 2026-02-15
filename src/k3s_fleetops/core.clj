(ns k3s-fleetops.core
  (:require
   [babashka.fs :as fs]
   [babashka.process :refer [shell]]
   [clojure.string :as str]))

(def dry-run
  {:option  "dry-run"
   :env     "DRY_RUN"
   :as      "Dry Run?"
   :type    :with-flag
   :default false})

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
                                        (fs/starts-with? f "fleet")
                                        (fs/starts-with? f "manifests")
                                        (fs/starts-with? f "target")))))
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
          (println (str "copy " file-path " - " target-directory))
          (fs/copy file-path target-directory {:replace-existing true}))))))

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(defn build
  [& [opts]]
  (println opts)
  (shell "mkdir -p target/argo-applications")
  (shell "touch target/argo-applications/.gitkeep")
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
                                    "jet -i edn -o yaml"
                                    (str (if verbose? "tee " "dd of=") target-path-string)]
                command            (str "sh -c \"" (str/join " | " parts) "\"")]
            (if dry-run?
              (println (str "[DRY-RUN] " command))
              (shell command))))))
    (build-yaml opts)))

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
              "_describe 'command' matches"
              "}"
              ""
              (str "compdef _" app-name " " app-name)]
        script (str/join "\n" args)]
    (println script)))

(defn completion-command
  [& [args]]
  (let [shell (first (:_arguments args))]
    (case shell
      "zsh"    (zsh-completion)
      :default (throw (ex-info "Unknown shell type" {:shell shell})))))

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
    {:command "tasks"
     :descriptions "Display tasks"
     :runs display-tasks}]})
