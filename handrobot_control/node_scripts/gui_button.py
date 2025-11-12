#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk
import rospy
from std_msgs.msg import String
import threading

class ButtonGridGUI:
    def __init__(self, master):
        self.master = master
        self.master.title("4x4 Button Publisher")

        # ROSパブリッシャーの初期化
        # /button_click トピックに String 型のメッセージを送信します
        self.pub = rospy.Publisher('/button_click', String, queue_size=10)

        # ボタンのラベルを定義（4x4の2次元リスト）
        button_labels = [
            ["SIT", "", "", ""],
            ["STAND", "BOW", "", ""],
            ["PAUSE", "STAND_WALK", "STAND_ROTATE", ""],
            ["", "", "", ""]
        ]

        # 4x4のグリッド状にボタンを作成
        for r, row in enumerate(button_labels):
            for c, label_text in enumerate(row):
                # 各ボタンに publish_message 関数を割り当て、そのボタンのラベルを引数として渡す
                btn = ttk.Button(
                    self.master,
                    text=label_text,
                    command=lambda text=label_text: self.publish_message(text)
                )
                # gridメソッドで配置 (sticky="nsew" でセルいっぱいに広げる)
                btn.grid(row=r, column=c, padx=5, pady=5, sticky="nsew")

        # ウィンドウのリサイズ時にボタンも伸縮するように設定
        for i in range(4):
            self.master.grid_columnconfigure(i, weight=1)
            self.master.grid_rowconfigure(i, weight=1)

    def publish_message(self, text):
        """ボタンが押されたときに呼び出される関数"""
        rospy.loginfo(f"Publishing: {text}")
        msg = String()
        msg.data = text
        self.pub.publish(msg)

def run_gui():
    """GUIのメインループを実行する関数"""
    root = tk.Tk()
    # ウィンドウの初期サイズを設定（オプション）
    root.geometry("400x300")
    app = ButtonGridGUI(root)
    root.mainloop()

if __name__ == "__main__":
    # ROSノードの初期化
    rospy.init_node('button_grid_gui', anonymous=True)

    # GUIを別スレッドで実行
    # これによりROSの通信処理とGUIの描画処理が並行して動きます
    gui_thread = threading.Thread(target=run_gui)
    gui_thread.start()

    # メインスレッドはROSの終了を監視
    rate = rospy.Rate(10) # 10Hz
    while not rospy.is_shutdown():
        # GUIスレッドが終了していたら（ウィンドウが閉じられたら）、ROSノードも終了させる
        if not gui_thread.is_alive():
            rospy.signal_shutdown("GUI window closed")
        rate.sleep()
