#!/usr/bin/env roseus
(load "package://roseus_smach/src/state-machine.l")
(ros::roseus-add-msgs "riberry_startup")

(defun func-check (userdata-alist)
  (format t "Execute state CHECK~%")
  (setq imu (cdr (assoc :imu userdata-alist)))
  (cond
   ((or (eq imu :none) (eq imu :bottom))
    (progn
      :update))
    ((eq imu :top)
     :help)
    (t
     imu)
    )
  )

(defun func-wait (userdata-alist)
  (format t "Execute state WAIT~%")
  (setq imu (cdr (assoc :imu userdata-alist)))
  ;; imuが:bottomになるのを待つ, timeoutで:failed
  :succeeded
)

(defun func-help (userdata-alist)
  (format t "Execute state HELP~%")
  :succeeded
)

(defun func-front (userdata-alist)
  (format t "Execute state FRONT~%")
  :succeeded
)

(defun func-back (userdata-alist)
  (format t "Execute state BACK~%")
  :succeeded
)

(defun func-left (userdata-alist)
  (format t "Execute state LEFT~%")
  :succeeded
)

(defun func-right (userdata-alist)
  (format t "Execute state RIGHT~%")
  :succeeded
)

(defun func-bottom (userdata-alist)
  (format t "Execute state BOTTOM~%")
  :succeeded
)

(defclass getup-smach
  :slots (sm userdata))

(defmethod getup-smach
  (:init
    ()
    (send self :make-state-machine)
    (ros::subscribe "/imu_orientation/imu_face" riberry_startup::ImuFace #'send self :imu-cb)
    )

  (:imu-cb
    (msg)
    (case (send msg :face)
      (0 (setf (cdr (assoc :imu userdata)) :none))
      (1 (setf (cdr (assoc :imu userdata)) :top))
      (2 (setf (cdr (assoc :imu userdata)) :bottom))
      (3 (setf (cdr (assoc :imu userdata)) :front))
      (4 (setf (cdr (assoc :imu userdata)) :back))
      (5 (setf (cdr (assoc :imu userdata)) :left))
      (6 (setf (cdr (assoc :imu userdata)) :right)))
    )

  (:make-state-machine
   ()
    (setq userdata (list (cons :imu :none)))
    (setq sm (instance state-machine :init))
    (send sm :add-node (instance state :init :BOTTOM 'func-bottom))
    (send sm :add-node (instance state :init :FRONT 'func-front))
    (send sm :add-node (instance state :init :BACK 'func-back))
    (send sm :add-node (instance state :init :LEFT 'func-left))
    (send sm :add-node (instance state :init :RIGHT 'func-right))
    (send sm :add-node (instance state :init :CHECK 'func-check))
    (send sm :add-node (instance state :init :HELP 'func-help))
    (send sm :add-node (instance state :init :WAIT 'func-wait))

    (send sm :goal-state :end)
    (send sm :start-state :CHECK)

    (send sm :add-transition :CHECK :HELP :help)
    (send sm :add-transition :CHECK :BOTTOM :bottom)
    (send sm :add-transition :CHECK :FRONT :front)
    (send sm :add-transition :CHECK :BACK :back)
    (send sm :add-transition :CHECK :LEFT :left)
    (send sm :add-transition :CHECK :RIGHT :right)
    (send sm :add-transition :CHECK :CHECK :update)

    (send sm :add-transition :BOTTOM :WAIT :succeeded)
    (send sm :add-transition :FRONT :WAIT :succeeded)
    (send sm :add-transition :BACK :WAIT :succeeded)
    (send sm :add-transition :LEFT :WAIT :succeeded)
    (send sm :add-transition :RIGHT :WAIT :succeeded)

    (send sm :add-transition :WAIT :CHECK :succeeded)
    (send sm :add-transition :WAIT :HELP :failed)

    (send sm :add-transition :HELP :end :failed)
    (send sm :add-transition :HELP :CHECK :succeeded)
    )

  (:execute
    ()
    (do-until-key
     (unix::sleep 1)
     (ros::spin-once)
     (ros::sleep)
     (send sm :execute userdata :step -1)
     )
    )
  )

(ros::roseus "get_up")
(setq gu (instance getup-smach :init))
(send gu :execute)
