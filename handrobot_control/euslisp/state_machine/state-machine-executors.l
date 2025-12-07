(load "state-machine-motions.l")
(load "janken.l")

(define-state-executor execute-state-stand :STANDING
  :transition (
    (servo-on-wait)
    (if (eq *current-state* :SITTING)
        (sit-to-stand)
      (progn
        (send *ri* :angle-vector *stand-pose* 2000)
        (send *ri* :wait-interpolation)))
    (setq *idle-time* 0.0)
    )
  :persistent (
    (standing-idle-frame)
    )
  )
)

(define-state-executor execute-state-pause :PAUSED
  :transition (
    (when *servo-subscriber*
      (ros::ros-info "Unsubscribing from servo_states")
      (ros::unsubscribe "servo_states")
      (setq *servo-subscriber* nil))
    )
  :persistent ()
)

(define-state-executor execute-state-janken :JANKEN
  :transition (
    (servo-on-wait)
    (when (eq *current-state* :SITTING)
      (send *ri* :angle-vector-sequence *janken-angle*
            (make-list (length *janken-angle*) :initial-element 1200))
      (send *ri* :wait-interpolation)
      )
    (when (eq *current-state* :UPRIGHT)
      (send *ri* :angle-vector-sequence *paper-to-rock-seq*
            (make-list (length *paper-to-rock-seq*) :initial-element 1200))
      (send *ri* :wait-interpolation))
    )
  :persistent ()
)

(define-action-executor execute-action-janken :JANKEN-PLAY
  :body (
    (play-janken)
  )
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
      (send *ri* :angle-vector #f(101.048 48.2963 -19.71 23.1525 -0.33749 48.8363 -39.6562 12.0488 -12.96 53.1563 -41.445 -8.43749 -12.6225 56.43 -41.7487 -16.9425 -1.38374 33.3113 -18.9337) 2000)
      (send *ri* :wait-interpolation)
      )
    )
  :persistent (
    (cond
      ((eq *walk-next-part* :PART1)
       (send *ri* :angle-vector-sequence *walk-angle-part1*
             (make-list (length *walk-angle-part1*) :initial-element 450))
       (send *ri* :wait-interpolation)
       (setq *walk-next-part* :PART2))

      ((eq *walk-next-part* :PART2)
       (send *ri* :angle-vector-sequence *walk-angle-part2*
             (make-list (length *walk-angle-part2*) :initial-element 450))
       (send *ri* :wait-interpolation)
       (setq *walk-next-part* :PART1))
      )
  )
)

(define-state-executor execute-state-sit :SITTING
  :transition (
    (when (eq *current-state* :STANDING)
      (stand-to-sit))
    (when (eq *current-state* :UPRIGHT)
      (send *ri* :angle-vector-sequence (reverse *upright-angle*)
            (make-list (length *upright-angle*) :initial-element 900))
      (send *ri* :wait-interpolation))
    (when (eq *current-state* :JANKEN)
      (send *ri* :angle-vector-sequence (reverse *janken-angle*)
            (make-list (length *janken-angle*) :initial-element 900))
      (send *ri* :wait-interpolation))
    (when (eq *current-state* :SIDE)
      (side-to-sit))
    (send *ri* :servo-off)
  )
  :persistent ()
  )

(define-state-executor execute-state-upright :UPRIGHT
  :transition (
    (servo-on-wait)
    (when (eq *current-state* :SITTING)
      (send *ri* :angle-vector-sequence *upright-angle*
            (make-list (length *upright-angle*) :initial-element 1200))
      (send *ri* :wait-interpolation))
  )
  :persistent ()
)

(define-state-executor execute-state-side :SIDE
  :transition (
    (servo-on-wait)
    (when (eq *current-state* :SITTING)
      (sit-to-side))
  )
  :persistent ()
)

(define-state-executor execute-state-grasp :GRASP
  :transition (
    (unless *is-grasping*
      (servo-on-wait)
      (when (or (eq *current-state* :SITTING) (eq *current-state* :PAUSED))
        (send *ri* :angle-vector #f(68.8838 52.7175 2.63251 3.98251 111.814 38.6438 90.2475 2.16001 126.731 17.7525 74.5538 -1.45124 124.234 14.0063 91.2938 1.65376 103.849 63.1125 82.0463) 2000)
        (send *ri* :wait-interpolation)
        (setq *grasp-switch* t)
        )))
  :persistent (
    (when *grasp-switch*
      (if *is-grasping*
        (progn
          (send *ri* :angle-vector #f(61.7288 44.9888 3.94876 -8.26874 34.8975 1.08001 37.2263 -13.8375 40.77 0.16876 31.2188 -2.12624 126.9 17.28 93.2513 -11.1375 101.891 66.3525 81.405) 2000)
          (send *ri* :wait-interpolation)
          (unix::sleep 2)
          (send *ri* :angle-vector #f(68.8838 52.7175 2.63251 3.98251 111.814 38.6438 90.2475 2.16001 126.731 17.7525 74.5538 -1.45124 124.234 14.0063 91.2938 1.65376 103.849 63.1125 82.0463) 2000)
          (send *ri* :wait-interpolation)
          (setq *is-grasping* nil)
          (setq *walk-mode* :ALL))
        (progn
          (tapping)
          (unix::sleep 1)
          (beckon)
          (unix::sleep 2)
          (send *ri* :angle-vector (elt *wheel-walk-145-angle* 0) 3000)
          (send *ri* :wait-interpolation)
          (setq *is-grasping* t)
          (setq *walk-mode* :145)))
      (setq *grasp-switch* nil)
    ))
)


(define-state-executor execute-state-rotate :STAND_ROTATE
  :transition (
    (unless (eq *current-state* :PAUSED)
      (send *ri* :angle-vector (elt *rotate-angle-part2* 3) 1000)
      (send *ri* :wait-interpolation)
      (setq *rotate-next-part* :PART1)
      )
    )
  :persistent (
    (cond
      ((eq *rotate-next-part* :PART1)
       (send *ri* :angle-vector-sequence *rotate-angle-part1*
             (make-list (length *rotate-angle-part1*) :initial-element 450))
       (send *ri* :wait-interpolation)
       (setq *rotate-next-part* :PART2))

      ((eq *rotate-next-part* :PART2)
       (send *ri* :angle-vector-sequence *rotate-angle-part2*
             (make-list (length *rotate-angle-part2*) :initial-element 450))
       (send *ri* :wait-interpolation)
       (setq *rotate-next-part* :PART1))
      )
  )
  )

(define-state-executor execute-state-wheel :WHEEL_WALK
  :transition (
    (servo-on-wait)
    (unless (or (eq *current-state* :PAUSED) (eq *current-state* :GRASP))
      (send *ri* :angle-vector #f(79.8525 44.3475 6.54751 8.57251 121.973 35.9775 65.205 3.47626 134.899 21.2625 45.6638 2.83501 132.874 16.3013 70.1325 11.8463 109.148 67.0275 55.62) 1000)
      (send *ri* :wait-interpolation)
      )
    )
  :persistent (
    (when (eq *walk-mode* :ALL)
      (send *ri* :angle-vector-sequence *wheel-walk-angle*
            (make-list (length *wheel-walk-angle*) :initial-element 500))
      (send *ri* :wait-interpolation))
    (when (eq *walk-mode* :145)
      (send *ri* :angle-vector-sequence *wheel-walk-145-angle*
            (make-list (length *wheel-walk-angle*) :initial-element 500))
      (send *ri* :wait-interpolation))
    )
  )


(define-state-executor execute-state-flexion :FLEXION
  :transition (
     (setq *servo-state-list* nil)
     (send *ri* :servo-on)
     (unless *servo-subscriber*
       (setq *servo-subscriber* (ros::subscribe "servo_states" kxr_controller::ServoStateArray #'servo-state-callback)))
     (while (null *servo-state-list*)
       (ros::spin-once)
       (ros::sleep))
     (setq *current-pose-vector* (send *ri* :state :potentio-vector))
  )
  :persistent (
    (let* ((target-joint-names (gethash *target-finger* *finger-joint-map*))
           (av (copy-seq *current-pose-vector*))
           (command-needed nil)
           (all-joints-at-limit t) ;; 全関節が限界か
           (all-joints-in-error t) ;; 全関節がエラーか
           )
      (dolist (joint-name target-joint-names)
        (let ((joint-suffix (subseq joint-name (- (length joint-name) 1))))
          (unless (string= joint-suffix "0")
            (let ((err (cdr (assoc joint-name *servo-state-list* :test #'string=)))
                  (j-id (position joint-name (send *robot* :joint-list)
                                  :test #'string=
                                  :key #'(lambda (j-obj) (send j-obj :name)))))
              ;; 1. 関節が正常かチェック
              (when (and err (<= err 1.6) j-id)
                (setq all-joints-in-error nil)
                (let ((curr-angle (aref av j-id)))
                  ;; 2. 角度が限界かチェック
                  (when (< curr-angle *flex-limit*)
                    (setq all-joints-at-limit nil)
                    (let* ((increment-ratio (cond
                                             ((string= joint-suffix "1") 1.0) ;; 根元: 100%
                                             ((string= joint-suffix "2") 0.8) ;; 中間: 80%
                                             ((string= joint-suffix "3") 0.6) ;; 先端: 60%
                                             (t 1.0)))
                           (increment-amount (* *flex-increment* increment-ratio)))
                      (setq new-angle (min *flex-limit*
                                           (+ curr-angle increment-amount))))
                    (setf (aref av j-id) new-angle)
                    (setq command-needed t))))
              ))))
      ;; 3. コマンド送信と状態保持
      (when command-needed
        (send *ri* :angle-vector av 0.1 :default-controller 0 :min-time 0.1)
        (send *ri* :wait-interpolation)
        (setq *current-pose-vector* av))
      ;; 4. 終了判定
      (when (or all-joints-at-limit all-joints-in-error)
        (send *ri* :cancel-angle-vector)
        (setq *target-state* :PAUSED))
      ))
  )

(define-state-executor execute-state-extension :EXTENSION
  :transition (
    (servo-on-wait)
    (setq *current-pose-vector* (send *ri* :state :potentio-vector))
    )
  :persistent (
    (let* ((target-joint-names (gethash *target-finger* *finger-joint-map*))
           (av (copy-seq *current-pose-vector*))
           (command-needed nil)
           (all-joints-at-limit t)
           )
      (dolist (joint-name target-joint-names)
        (unless (string= (subseq joint-name (- (length joint-name) 1)) "0")
          (let* ((j-id (position joint-name (send *robot* :joint-list)
                                 :test #'string=
                                 :key #'(lambda (j-obj) (send j-obj :name))))
                 (curr-angle (aref av j-id)))
            (when (> curr-angle *extend-limit*)
              (setq all-joints-at-limit nil)
              (setq new-angle (max *extend-limit*
                                   (- curr-angle *extend-decrement*)))
              (setf (aref av j-id) new-angle)
              (setq command-needed t)))))

      (when command-needed
        (send *ri* :angle-vector av 0.1 :default-controller 0 :min-time 0.1)
        (send *ri* :wait-interpolation)
        (setq *current-pose-vector* av))

      (when all-joints-at-limit
        (send *ri* :cancel-angle-vector)
        (setq *target-state* :PAUSED))
      ))
  )
