### Setup
```
pip install scikit-robot==0.2.17
pip install zacro==1.0.8
mkdir -p ~/ros/hand/src
cd ~/ros/hand/src
git clone https://github.com/nakane11/walking_hand
cd ~/ros/hand
catkin init
catkin build handrobot_model
```
### urdfを生成
#### A. すべての指を含んだURDF
`-o`で出力パスを指定
```
source ~/ros/hand/devel/setup.bash
roscd handrobot_model
python scripts/generate_hand_urdf.py hand_robot.xacro -o hand_robot.urdf
```
#### B. 特定の指を除外したURDF
`--exclude`オプションに続いて，除外したい指の名前をスペース区切りで指定
```
python scripts/generate_hand_urdf.py hand_robot.xacro -o hand_robot_without_thumb_little.urdf --exclude thumb little
```
