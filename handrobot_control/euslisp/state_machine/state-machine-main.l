(load "state-machine-utils.l")
(load "state-machine-functions.l")
(require "package://kxreus/euslisp/kxr-interface.l")

;; (defun ros-command-callback (msg)
;;   "ROSコマンドを受け取り、目標状態をセット"
;;   (let ((command (send msg :data)))
;;     (cond
;;       ;; 持続的状態
;;       ((string= command "SIT")   (setq *target-state* :SITTING))
;;       ((string= command "STAND") (setq *target-state* :STANDING))

;;       ;; 一時的状態 (アクション)
;;       ((string= command "BOW")
;;        ;; アクションを実行できるかチェック
;;        (when (eq *current-state* :STANDING)
;;          (setq *return-state* *current-state*) ;; 戻り先を記憶
;;          (setq *target-state* :BOW)))         ;; アクションをターゲットに

;;       (t (warn "Unknown command: ~A~%" command))
;;       )))

;; --- 4. メインループ ---
(defun demo-main-loop ()
  (warn "Demo loop started. Waiting for commands...")

  (ros::rate 20)
  (do-until-key
    ;; --- 状態（State）の実行 ---
    (let ((executor-func-name (gethash *target-state* *state-dispatch-table*)))

      (if executor-func-name
          ;; もし対応する関数が見つかったら実行
          (funcall executor-func-name)

          ;; もし見つからなかったら (起動時や未定義のコマンド)
          (when (not (eq *target-state* :STANDING))
             (warn "No executor for ~A. Defaulting to SITTING." *target-state*)
             (setq *target-state* :STANDING))
          ))

    ;; --- ROSのチェックと待機 ---
    (ros::spin-once)
    (ros::sleep)
  ))

;; (kxr-init :create-viewer nil)
;; (demo-main-loop)
