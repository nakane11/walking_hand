#!/usr/bin/env roseus

(require "package://kxreus/euslisp/kxr-interface.l")
(ros::roseus-add-msgs "kxr_controller")
(ros::roseus-add-msgs "std_msgs")

(defclass button-control
  :slots (index2joint servo-on-list servo-state-list button-list
                      flexing-flag-list robot-joint-list)
  )

(defmethod button-control
  (:init
    ()
    (setq index2joint (list (cons 0 (list "THUMB0" "THUMB1" "THUMB2"))
                            (cons 1 (list "INDEX0" "INDEX1" "INDEX2" "INDEX3"))
                            (cons 2 (list "MIDDLE0" "MIDDLE1" "MIDDLE2" "MIDDLE3"))
                            (cons 3 (list "RING0" "RING1" "RING2" "RING3"))
                            (cons 4 (list "LITTLE0" "LITTLE1" "LITTLE2" "LITTLE3"))))
    (setq button-list (make-list 5 :initial-element 0))
    (setq flexing-flag-list (make-list 5 :initial-element nil))
    (setq robot-joint-list (send *robot* :joint-list))
    (ros::subscribe "/fullbody_controller/servo_on_off_real_interface/state" kxr_controller::ServoOnOff #'send self :servo-on-cb)
    (ros::subscribe "/servo_states" kxr_controller::ServoStateArray #'send self :servo-state-cb)
    (ros::subscribe "/adc_button_state" std_msgs::UInt8MultiArray #'send self :button-cb 5)
    )

  (:servo-on-cb
   (msg)
    (setq servo-on-list (mapcar #'(lambda (name state) (cons name state))
                                (send msg :joint_names) (send msg :servo_on_states)))
    )

  (:servo-state-cb
    (msg)
    (setq servo-state-list nil)
    (dolist (servo (send msg :servos))
      (let ((name (send servo :name))
            (err (send servo :error)))
        (setq servo-state-list (cons (cons name err) servo-state-list))
        ))
    )

  (:switch-servo
   (idx)
   (setq on-list nil)
   (setq off-list nil)
    (dolist (joint (cdr (assoc idx index2joint)))
      (if (cdr (assoc joint servo-on-list :test #'string=))
          (setq off-list (cons joint off-list))
        (setq on-list (cons joint on-list))))
    (when on-list
      (send *ri* :servo-on :names on-list))
    (when off-list
      (send *ri* :servo-off :names off-list))
    )

(:flexion
   (idx)
   (format t "Start flexion for index: ~A~%" idx)
   (setf (elt flexing-flag-list idx) t)

   ;; loop while button is long-pressed
   (while (= (elt button-list idx) 2)
     (setq av (send *ri* :state :potentio-vector))
     (setq command-needed nil)

     (dolist (joint (cdr (assoc idx index2joint)))
       (unless (string= (subseq joint (- (length joint) 1)) "0")
         ;; exclude root joints named "~0"
         (setq err (cdr (assoc joint servo-state-list :test #'string=)))

         (when (and err (<= err 2))
           (setq j-id (position joint robot-joint-list
                                :test #'string=
                                :key #'(lambda (j-obj) (send j-obj :name))))
           (when j-id
             (let* ((curr-angle (aref av j-id)))
               (when (< curr-angle 90.0)
                 (setq new-angle (min 90.0 (+ curr-angle 10.0)))
                 (setf (aref av j-id) new-angle)
                 (setq command-needed t))
               ))
           )))

     (when command-needed
       (send *ri* :angle-vector av 60))

     ;; update button-list
     (ros::spin-once)
     (ros::sleep)
     )

   (format t "Stop flexion for index: ~A~%" idx)
   (setf (elt flexing-flag-list idx) nil)
   )

  (:button-cb
   (msg)
   (let ((btn (coerce (send msg :data) cons)))
     (setq button-list btn)
      (dotimes (i (length btn))
         (case (elt btn i)
           (1 ;; single click
            (send self :switch-servo i))
           (2 ;; long press
            (unless (elt flexing-flag-list i)
            (send self :flexion i)))
           ))))

 )


(ros::roseus "button_control")
(kxr-init :create-viewer nil)
(setq bc (instance button-control :init))
(ros::rate 20)
(do-until-key
 (ros::spin-once)
 (ros::sleep)
 )
