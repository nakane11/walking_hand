import argparse
import subprocess
import tempfile
import os
import sys
import xml.etree.ElementTree as ET

def generate_urdf(input_xacro, output_urdf, exclude_fingers=None):
    """
    PythonのXMLライブラリを使い、xacroファイルから特定の指の要素を削除してURDFを生成する。
    """
    if exclude_fingers is None:
        exclude_fingers = []

    print(f"元のXACROファイル: {input_xacro}")

    try:
        ET.register_namespace('xacro', "http://ros.org/wiki/xacro")
        tree = ET.parse(input_xacro)
        root = tree.getroot()
    except Exception as e:
        print(f"エラー: XACROファイルの読み込みまたは解析に失敗しました。 {e}")
        sys.exit(1)

    if not exclude_fingers:
        print("除外する指はありません。")
        source_xacro_path = input_xacro
    else:
        print(f"除外する指: {', '.join(exclude_fingers)}")

        nodes_to_remove = []
        for node in root.iter():
            prefix = node.get('{http://ros.org/wiki/xacro}prefix')
            if prefix is None:
                 prefix = node.get('prefix')

            if prefix:
                for finger_name in exclude_fingers:
                    if prefix.startswith(finger_name + "_module"):
                        nodes_to_remove.append(node)
                        break

        if nodes_to_remove:
            print(f"削除対象の要素を{len(nodes_to_remove)}個見つけました。")
            parent_map = {c: p for p in root.iter() for c in p}
            for node in nodes_to_remove:
                if node in parent_map:
                    parent = parent_map[node]
                    parent.remove(node)

        with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.xacro') as temp_f:
            tree.write(temp_f, encoding='utf-8', xml_declaration=True)
            source_xacro_path = temp_f.name

        print(f"一時ファイルを生成: {source_xacro_path}")

    command = ["zacro", source_xacro_path, "--remove-root-link", "world", "--tree", "-o", output_urdf]
    print(f"\n実行するコマンド: {' '.join(command)}")

    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print("URDFファイルの生成に成功しました！")

        if result.stdout:
            print("\n--- zacro stdout ---")
            print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"\nURDFファイルの生成中にエラーが発生しました。\n--- zacro stderr ---\n{e.stderr}")
    finally:
        if source_xacro_path != input_xacro and os.path.exists(source_xacro_path):
            os.remove(source_xacro_path)
            print(f"一時ファイルを削除: {source_xacro_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="XMLライブラリを使ってxacroファイルから指を削除しURDFを生成します。")
    parser.add_argument("input_file", nargs="?", default="hand_robot.xacro", help="入力xacroファイル")
    parser.add_argument("-o", "--output", default="hand_robot.urdf", help="出力URDFファイル名")
    parser.add_argument("-e", "--exclude", nargs='+', choices=["thumb", "index", "middle", "ring", "little"], help="除外する指のリスト")

    args = parser.parse_args()
    generate_urdf(args.input_file, args.output, args.exclude)
