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
)

(define-state-executor execute-state-pause :PAUSED
  :transition ()
  :persistent ()
)

(define-action-executor execute-action-bow :BOW
  :body (
    (play-curtsy-motion :base-pose *stand-pose* :duration 1000)
  )
)

(define-state-executor execute-state-walk :STAND_WALK
  :transition (
    (unless (eq *current-state* :PAUSED)
      (setq *walk-next-part* :PART1)
      )
    )
  :persistent (
    (cond
      ((eq *walk-next-part* :PART1)
       (send *ri* :angle-vector-sequence *walk-angle-part1*
             (make-list (length *walk-angle-part1*) :initial-element 600))
       (send *ri* :wait-interpolation)
       (setq *walk-next-part* :PART2))

      ((eq *walk-next-part* :PART2)
       (send *ri* :angle-vector-sequence *walk-angle-part2*
             (make-list (length *walk-angle-part2*) :initial-element 600))
       (send *ri* :wait-interpolation)
       (setq *walk-next-part* :PART1))
      )
  )
)

(define-state-executor execute-state-sit :SITTING
  :transition (
    (stand-to-sit)
    (send *ri* :servo-off)
  )
  :persistent ()
)
