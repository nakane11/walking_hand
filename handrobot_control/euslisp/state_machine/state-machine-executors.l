(ros::load-ros-manifest "kxr_controller")
(load "state-machine-motions.l")

(define-state-executor execute-state-stand :STANDING
  :transition (
    (ros::ros-info "Transition: -> STAND")
    (send *ri* :servo-on)
    (while t
      (setq msg (one-shot-subscribe "/fullbody_controller/servo_on_off_real_interface/state" kxr_controller::ServoOnOff))
      (when (every #'identity (send msg :servo_on_states))
        (return))
      (ros::spin-once)
      (ros::sleep))
    (send *ri* :angle-vector *stand-pose* 2000)
    (send *ri* :wait-interpolation)
    (setq *idle-time* 0.0)
    (ros::ros-info "Transition: STAND complete.")
  )
  :persistent (
    (standing-idle-frame)
  )
)

(define-action-executor execute-action-bow :BOW
  :body (
    (ros::ros-info "Action: Executing Bow...")
    (play-curtsy-motion :base-pose *stand-pose* :duration 1000)
    (setq *idle-time* 0.0)
    (ros::ros-info "Action: Bow finished.")
  )
)
