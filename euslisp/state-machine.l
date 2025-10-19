#!/usr/bin/env roseus
(load "package://roseus_smach/src/state-machine.l")
(ros::roseus-add-msgs "riberry_startup")
(ros::load-ros-manifest "riberry_startup")
(require "package://kxreus/euslisp/kxr-interface.l")

(defun send-request (name)
  (setq req (instance riberry_startup::SelectMotionRequest :init))
  (send req :data t)
  (send req :name name)
  (setq res (ros::service-call "/teaching_mode/play" req))
  res
  )

(defun help-pose (step)
  (setq angle-list (list
                    #f(4.69126 61.425 6.04126 6.00751 15.7613 0.16876 -16.4362 -0.43874 13.1963 -0.94499 -9.11249 -2.93624 10.4625 -0.10124 -11.07 -7.12124 10.8338 -0.94499 0.03376)
                    #f(128.453 101.486 44.3475 6.31126 -20.6212 28.6538 -4.35374 -0.43874 -20.6212 15.4238 28.9575 -5.53499 -24.6712 20.25 22.3763 -12.015 -26.1225 28.4175 3.88126)
                    #f(129.094 101.486 44.3475 16.0313 84.5438 101.655 48.6338 6.27751 94.635 84.8475 29.5988 5.50126 87.9188 85.6575 50.4563 -3.54374 94.3313 97.4025 69.3563)
                    #f(128.453 101.486 44.3475 6.31126 -20.6212 28.6538 -4.35374 -0.43874 -20.6212 15.4238 28.9575 -5.53499 -24.6712 20.25 22.3763 -12.015 -26.1225 28.4175 3.88126)
                    #f(4.69126 61.425 6.04126 6.00751 15.7613 0.16876 -16.4362 -0.43874 13.1963 -0.94499 -9.11249 -2.93624 10.4625 -0.10124 -11.07 -7.12124 10.8338 -0.94499 0.03376)))
  (send *ri* :servo-on)
  (dotimes (i step)
    (send *ri* :angle-vector-sequence angle-list (make-list (length angle-list) :initial-element 1200))
    (send *ri* :wait-interpolation))
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
    (if (>  (cdr cnt) 80)
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
          (print (cdr cnt))
          :update)
         ))
)))

(defun func-help (userdata-alist)
  (format t "Execute state HELP~%")
  (help-pose 2)
  (ros::rate 10) ;;(send *ri* :angle-vector) change ros rate internally
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

     (when (= imu-counter 10)
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
    (send sm :add-transition :HELP :WAIT :succeeded)
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
(kxr-init :create-viewer nil)
(setq gu (instance getup-smach :init))
(send gu :execute)
