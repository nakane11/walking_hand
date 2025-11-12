(load "state-machine-utils.l")
(load "state-machine-executors.l")
(require "package://kxreus/euslisp/kxr-interface.l")
(ros::load-ros-manifest "std_msgs")

(defun ros-command-callback (msg)
  (let ((command (send msg :data)))
    (cond
      ;; 持続的状態
      ;; ((string= command "SIT")   (setq *target-state* :SITTING))
      ((string= command "STAND") (setq *target-state* :STANDING))
      ((string= command "PAUSE") (setq *target-state* :PAUSED))
      ((string= command "STAND_WALK")
        (when (or (eq *current-state* :STANDING) (eq *current-state* :PAUSED))
          (setq *target-state* :STAND_WALK)))

      ;; 一時的状態 (アクション)
      ((string= command "BOW")
       ;; アクションを実行できるかチェック
       (when (eq *current-state* :STANDING)
         (setq *return-state* *current-state*) ;; 戻り先を記憶
         (setq *target-state* :BOW)))         ;; アクションをターゲットに

      (t (warn "Unknown command: ~A~%" command))
      )))

;; --- 4. メインループ ---
(defun demo-main-loop ()
  (ros::rate 20)
  (ros::subscribe "/button_click" std_msgs::String #'ros-command-callback)
  (do-until-key
    (let ((executor-func-name (gethash *target-state* *state-dispatch-table*)))

      (if executor-func-name
          (funcall executor-func-name)

          ;; もし見つからなかったら (起動時や未定義のコマンド)
          (when (not (eq *target-state* :STANDING))
             (warn "No executor for ~A. Defaulting to STANDING." *target-state*)
             (setq *target-state* :STANDING))
          ))

    (ros::spin-once)
    (ros::sleep)
  ))

(kxr-init :create-viewer nil)
(demo-main-loop)
