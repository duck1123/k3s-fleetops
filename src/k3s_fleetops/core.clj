(ns k3s-fleetops.core
  (:require
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
