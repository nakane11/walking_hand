#!/usr/bin/env roseus
(load "package://roseus_smach/src/state-machine.l")
(ros::roseus-add-msgs "riberry_startup")
(ros::load-ros-manifest "riberry_startup")

(defun send-request (name)
  (setq req (instance riberry_startup::SelectMotionRequest :init))
  (send req :data t)
  (send req :name name)
  (setq res (ros::service-call "/teaching_mode/play" req))
  res
  )

(defun func-check (userdata-alist)
  ;; (format t "Execute state CHECK~%")
  (setq imu (cdr (assoc :imu userdata-alist)))
  (cond
   ((or (eq imu :none) (eq imu :bottom))
      :update)
   ((eq imu :top)
    :help)
   (t
    imu)
   )
  )

(defun func-wait (userdata-alist)
  (format t "Execute state WAIT~%")
  (let ((cnt (assoc :wait-count userdata-alist)))
    (if (>  (cdr cnt) 40)
        (progn
          (setf (cdr cnt) 0)
          :failed)
      (let ((imu (cdr (assoc :imu userdata-alist))))
        (cond
         ((eq imu :bottom)
          (setf (cdr cnt) 0)
          :succeeded)
         (t
          (incf (cdr cnt))
          :update)
         ))
)))

(defun func-help (userdata-alist)
  (format t "Execute state HELP~%")
  :succeeded
)

(defun func-front (userdata-alist)
  (format t "Execute state FRONT~%")
  (send-request "front2bottom")
  :succeeded
)

(defun func-back (userdata-alist)
  (format t "Execute state BACK~%")
  (send-request "back2bottom")
  :succeeded
)

(defun func-left (userdata-alist)
  (format t "Execute state LEFT~%")
  (send-request "left2bottom")
  :succeeded
)

(defun func-right (userdata-alist)
  (format t "Execute state RIGHT~%")
  (send-request "right2bottom")
  :succeeded
)

(defclass getup-smach
  :slots (sm userdata last-imu-value imu-counter))

(defmethod getup-smach
  (:init
    ()
    (setq last-imu-value :none)
    (setq imu-counter 0)
    (send self :make-state-machine)
    (ros::wait-for-service "/teaching_mode/play")
    (ros::subscribe "/imu_orientation/imu_face" riberry_startup::ImuFace #'send self :imu-cb)
    )

  (:imu-cb
   (msg)
   (let ((current-imu-face
           (case (send msg :face)
             (0 :none)
             (1 :top)
             (2 :bottom)
             (3 :front)
             (4 :back)
             (5 :left)
             (6 :right))))

     (if (eq current-imu-face last-imu-value)
         (incf imu-counter)
       (progn
         (setq imu-counter 1)
         (setq last-imu-value current-imu-face)))

     (when (= imu-counter 20)
       (setf (cdr (assoc :imu userdata)) last-imu-value)
       (format t "IMU value updated to ~A (20 consecutive readings)~%" last-imu-value)
       )
     ))

  (:make-state-machine
   ()
    (setq userdata (list (cons :imu :none) (cons :wait-count 0)))
    (setq sm (instance state-machine :init))
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
    (send sm :add-transition :CHECK :FRONT :front)
    (send sm :add-transition :CHECK :BACK :back)
    (send sm :add-transition :CHECK :LEFT :left)
    (send sm :add-transition :CHECK :RIGHT :right)
    (send sm :add-transition :CHECK :CHECK :update)

    (send sm :add-transition :FRONT :WAIT :succeeded)
    (send sm :add-transition :BACK :WAIT :succeeded)
    (send sm :add-transition :LEFT :WAIT :succeeded)
    (send sm :add-transition :RIGHT :WAIT :succeeded)

    (send sm :add-transition :WAIT :CHECK :succeeded)
    (send sm :add-transition :WAIT :HELP :failed)
    (send sm :add-transition :WAIT :WAIT :update)

    (send sm :add-transition :HELP :end :failed)
    (send sm :add-transition :HELP :CHECK :succeeded)
    )

  (:execute
    ()
    (ros::rate 10)
    (do-until-key
     (ros::spin-once)
     (ros::sleep)
     (send sm :execute userdata :step -1)
     )
    )
  )

(ros::roseus "get_up")
(setq gu (instance getup-smach :init))
(send gu :execute)
