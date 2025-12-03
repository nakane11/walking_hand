#!/usr/bin/env roseus

(load "state-machine-utils.l")
(load "state-machine-executors.l")
(require "package://kxreus/euslisp/kxr-interface.l")
(ros::load-ros-manifest "std_msgs")

(defun ros-command-callback (msg)
  (let ((command (send msg :data)))
    (cond
      ;; 持続的状態
      ((string= command "SIT")
        (when (or (eq *current-state* :STANDING) (eq *current-state* :PAUSED) (eq *current-state* :UPRIGHT))
          (setq *target-state* :SITTING)))
      ((string= command "UPRIGHT")
        (when (eq *current-state* :SITTING)
          (setq *target-state* :UPRIGHT)))
      ((string= command "STAND") (setq *target-state* :STANDING))
      ((string= command "PAUSE") (setq *target-state* :PAUSED))
      ((string= command "STAND_WALK")
        (when (or (eq *current-state* :STANDING) (eq *current-state* :PAUSED))
          (setq *target-state* :STAND_WALK)))
      ((string= command "STAND_ROTATE")
        (when (or (eq *current-state* :STANDING) (eq *current-state* :PAUSED))
          (setq *target-state* :STAND_ROTATE)))
      ((string= command "WHEEL_WALK")
       (when (or (eq *current-state* :SITTING) (eq *current-state* :PAUSED))
         (setq *target-state* :WHEEL_WALK)))
      ((string= command "FLEXION")
       (setq *target-state* :FLEXION))
      ((string= command "EXTENSION")
       (setq *target-state* :EXTENSION))

      ;; 一時的状態 (アクション)
      ((string= command "BOW")
       ;; アクションを実行できるかチェック
       (when (eq *current-state* :STANDING)
         (setq *return-state* *current-state*) ;; 戻り先を記憶
         (setq *target-state* :BOW)))         ;; アクションをターゲットに

      ((member command *finger-names* :test #'string=)
       (setq *target-finger* (intern command "KEYWORD"))
       (print *target-finger*))

      (t (warn "Unknown command: ~A~%" command))
      )
    ))

;; --- 4. メインループ ---
(defun demo-main-loop (ns)
  (ros::rate 20)
  (setq button-topic (if ns (format nil "~A~A" ns "/button_click") "/button_click"))
  (ros::subscribe button-topic std_msgs::String #'ros-command-callback)
  (do-until-key
    (let ((executor-func-name (gethash *target-state* *state-dispatch-table*)))

      (if executor-func-name
          (funcall executor-func-name)

          ;; もし見つからなかったら (起動時や未定義のコマンド)
          (when (not (eq *target-state* :SITTING))
             (warn "No executor for ~A. Defaulting to SITTING." *target-state*)
             (setq *target-state* :SITTING))
          ))

    (ros::spin-once)
    (ros::sleep)
  ))

(ros::roseus "state_machine_main")
(setq ns (ros::get-param "~namespace" nil))
(kxr-init :create-viewer nil :namespace ns :controller-timeout 40)
(send *ri* :send-stretch :value 127)
(demo-main-loop ns)
