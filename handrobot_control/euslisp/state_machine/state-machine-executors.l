(ros::load-ros-manifest "kxr_controller")
(load "state-machine-motions.l")

(define-state-executor execute-state-stand :STANDING
  :transition (
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
  )
  :persistent (
    (standing-idle-frame)
  )
)

(define-action-executor execute-action-bow :BOW
  :body (
    (play-curtsy-motion :base-pose *stand-pose* :duration 1000)
    (setq *idle-time* 0.0)
  )
  )

;; (define-state-executor execute-state-sit :SITTING
;;   :transition (
;;     (send *ri* :angle-vector *sit-pose* 2000)
;;     (send *ri* :wait-interpolation)
;;     (send *ri* :servo-off)
;;   )
;;   :persistent ()
;; )
