#!/usr/bin/env roseus
(require "package://kxreus/euslisp/kxr-interface.l")
(require "package://handrobot_model/hand_robot.l")

(ros::roseus "test")
(setq ns (ros::get-param "~namespace" "blue"))
(kxr-init :create-viewer nil :namespace ns :controller-timeout 40)
(send *ri* :send-stretch :value 127)
(hand_robot)
;; joint-listの順番を変更
(let* ((ordered-names '(
           ;; THUMB 0, 1, 2
           "thumb_module1_joint1" "thumb_module2_joint1" "thumb_module3_joint1"
           ;; INDEX 0, 1, 2, 3
           "index_module1_joint1" "index_module1_joint2" "index_module2_joint1" "index_module3_joint1"
           ;; MIDDLE 0, 1, 2, 3
           "middle_module1_joint1" "middle_module1_joint2" "middle_module2_joint1" "middle_module3_joint1"
           ;; RING 0, 1, 2, 3
           "ring_module1_joint1" "ring_module1_joint2" "ring_module2_joint1" "ring_module3_joint1"
           ;; LITTLE 0, 1, 2, 3
           "little_module1_joint1" "little_module1_joint2" "little_module2_joint1" "little_module3_joint1"
           ))
       ;; 現在のjoint-listから、名前をキーにしてオブジェクトを抽出
       (new-joints (mapcar #'(lambda (name)
                               (find-if #'(lambda (j) (string-equal name (send j :name)))
                                        (send *hand_robot* :get-val 'joint-list)))
                           ordered-names)))

  ;; nilが含まれていないか（名前間違いがないか）チェックして書き換え
  (if (member nil new-joints)
      (format t "Error: Missing joints in the list!~%")
    (send *hand_robot* :set-val 'joint-list new-joints)))

(unless (boundp '*irtviewer*)
  (make-irtviewer))
(send *irtviewer* :viewer :viewing :look #f(1196.51 -635.794 386.592) #f(44.4977 -98.6004 207.95) #f(0.0 0.0 1.0))
(send *irtviewer* :objects (list *hand_robot*))

(setq k-list (list (cons :thumb (list 1 1 1))
                   (cons :index (list 1 0.5 0.1))
                   (cons :middle (list 1 0.1 0.05))
                   (cons :ring (list 1 1 1))
                   (cons :little (list 1 1 1))))

(defun get-finger-min-angles (robot finger-name)
  (let* ((f-str (string-downcase (string finger-name)))
         (m1-key (intern (string-upcase (format nil "~A_MODULE1_JOINT2" f-str)) "KEYWORD"))
         (m2-key (intern (string-upcase (format nil "~A_MODULE2_JOINT1" f-str)) "KEYWORD"))
         (m3-key (intern (string-upcase (format nil "~A_MODULE3_JOINT1" f-str)) "KEYWORD")))
    (list 0
          (send (send robot m1-key) :min-angle)
          (send (send robot m2-key) :min-angle)
          (send (send robot m3-key) :min-angle))))

(defun get-thumb-min-angles (robot)
  (list (send (send robot :thumb_module1_joint1) :min-angle)
        (send (send robot :thumb_module2_joint1) :min-angle)
        (send (send robot :thumb_module3_joint1) :min-angle)))

(setq neutral-angle
      (list (cons :thumb  (list 0 -39.9925 -39.9925))
            (cons :index  (get-finger-min-angles *hand_robot* :index))
            (cons :middle (get-finger-min-angles *hand_robot* :middle))
            (cons :ring   (get-finger-min-angles *hand_robot* :ring))
            (cons :little (get-finger-min-angles *hand_robot* :little))))

(defun set-finger-angles (robot finger-key angles)
  (let ((f-str (string-downcase (string finger-key))))
    (cond
     ((eq finger-key :thumb)
      (send (send robot :thumb_module1_joint1) :joint-angle (elt angles 0))
      (send (send robot :thumb_module2_joint1) :joint-angle (elt angles 1))
      (send (send robot :thumb_module3_joint1) :joint-angle (elt angles 2)))
     (t
      (let ((m1-key (intern (string-upcase (format nil "~A_MODULE1_JOINT2" f-str)) "KEYWORD"))
            (m2-key (intern (string-upcase (format nil "~A_MODULE2_JOINT1" f-str)) "KEYWORD"))
            (m3-key (intern (string-upcase (format nil "~A_MODULE3_JOINT1" f-str)) "KEYWORD")))
        (send (send robot m1-key) :joint-angle (elt angles 1))
        (send (send robot m2-key) :joint-angle (elt angles 2))
        (send (send robot m3-key) :joint-angle (elt angles 3)))))))

(defun update-finger-with-limits (robot finger-key delta-l)
  (let* ((ks (cdr (assoc finger-key k-list)))
         (neutrals (cdr (assoc finger-key neutral-angle)))
         (joints (cond
                  ((eq finger-key :thumb)
                   (list (send robot :thumb_module1_joint1)
                         (send robot :thumb_module2_joint1)
                         (send robot :thumb_module3_joint1)))
                  (t
                   (let ((f-str (string-downcase (string finger-key))))
                     (list nil ; module1_joint2に対応させるためのダミー
                           (send robot (intern (string-upcase (format nil "~A_MODULE1_JOINT2" f-str)) "KEYWORD"))
                           (send robot (intern (string-upcase (format nil "~A_MODULE2_JOINT1" f-str)) "KEYWORD"))
                           (send robot (intern (string-upcase (format nil "~A_MODULE3_JOINT1" f-str)) "KEYWORD")))))))
         ;; k-listと関節オブジェクトをペアにする (nilを除外)
         (active-info nil)
         (remaining-dl (float delta-l)))

    ;; 1. 初期角度をセット（現在の角度ではなくneutralからの相対値で計算する場合）
    ;; ※ 既に限界に達しているかチェックするための準備
    (let ((loop-continue t))
      (while (and loop-continue (> remaining-dl 0.001))
        (setq active-info nil)
        (setq loop-continue nil)

        ;; 現在まだ動かせる(angle < max-angle)関節と、そのk値をリストアップ
        (let ((idx (if (eq finger-key :thumb) 0 1)))
          (dolist (k ks)
            (let* ((j (elt joints idx))
                   (curr (if j (send j :joint-angle) 0))
                   (max-a (if j (send j :max-angle) 0)))
              (if (and j (< curr (- max-a 0.01))) ; 余裕がある関節
                  (push (list j k (- max-a curr)) active-info)))
            (setq idx (1+ idx))))

        (if (null active-info)
            (setq remaining-dl 0.0) ; 全ての関節が限界なら終了
          (let* ((sum-inv-k (reduce #'+ (mapcar #'(lambda (x) (/ 1.0 (float (second x)))) active-info)))
                 (next-remaining-dl 0.0))

            (dolist (info active-info)
              (let* ((j (first info))
                     (k (second info))
                     (headroom (third info))
                     ;; この関節に割り当てたい角度変位 (r=1と仮定)
                     (d-theta (* (/ (/ 1.0 (float k)) sum-inv-k) remaining-dl)))

                (if (> d-theta headroom)
                    ;; 限界を超える場合：限界まで動かし、余った分を次に回す
                    (progn
                      (send j :joint-angle (+ (send j :joint-angle) headroom))
                      (setq next-remaining-dl (+ next-remaining-dl (- d-theta headroom)))
                      (setq loop-continue t))
                  ;; 限界を超えない場合：そのまま動かす
                  (send j :joint-angle (+ (send j :joint-angle) d-theta)))))
            (setq remaining-dl next-remaining-dl)))))

    (send robot :angle-vector)))

;; (dolist (pair neutral-angle)
;;   (set-finger-angles *hand_robot* (car pair) (cdr pair)))
;; (send *irtviewer* :draw-objects)
;; (send *ri* :angle-vector (send *hand_robot* :angle-vector) 2000)
;; (send *ri* :wait-interpolation)

;; (dotimes (i 50)
;;   (let ((pull-amount (* i 2.0)))
;;     (dolist (f '(:thumb :index :middle :ring :little))
;;       (update-finger-with-limits *hand_robot* f pull-amount)
;;       )
;;     (send *ri* :angle-vector (send *hand_robot* :angle-vector) 100)
;;     (send *ri* :wait-interpolation)

;;     (send *irtviewer* :draw-objects)
;;     ;; (unix:usleep 100000)
;;     ))

;; 指の振り上げを定義
;; 歩容の候補を見つける
;; kを変えて歩く
