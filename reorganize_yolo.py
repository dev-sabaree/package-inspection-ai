#!/usr/bin/env python3
"""
Reorganize a Roboflow-style YOLO dataset into the standard layout:

vip/
├── images/{train,val,test}/
├── labels/{train,val,test}/
└── data.yaml

Usage:
    python reorganize_yolo.py                # uses ./vip
    python reorganize_yolo.py path/to/vip
    python reorganize_yolo.py vip --dry-run  # preview only
"""

import argparse
import re
import shutil
from pathlib import Path

IMAGE_EXTS = {".jpg", ".jpeg", ".png"}
LABEL_EXTS = {".txt"}

# source folder name -> destination split name
SPLITS = {"train": "train", "valid": "val", "test": "test"}

YAML_HEADER = """path: .
train: images/train
val: images/val
test: images/test
"""

# top-level keys we replace in data.yaml (everything else, e.g. names/nc, is kept)
PATH_KEYS = re.compile(r"^(path|train|val|valid|test)\s*:")


def move_file(src: Path, dst_dir: Path, dry_run: bool) -> bool:
    dst = dst_dir / src.name
    if dst.exists():
        print(f"  [skip] {dst} already exists, leaving {src} in place")
        return False
    if not dry_run:
        dst_dir.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst))
    return True


def process_split(root: Path, src_name: str, dst_name: str, dry_run: bool) -> None:
    src_dir = root / src_name
    if not src_dir.is_dir():
        print(f"[warn] '{src_name}' folder not found, skipping")
        return

    img_dir = root / "images" / dst_name
    lbl_dir = root / "labels" / dst_name
    n_img = n_lbl = 0

    # Works for both flat splits and Roboflow's train/images + train/labels layout
    for f in sorted(src_dir.rglob("*")):
        if not f.is_file():
            continue
        ext = f.suffix.lower()
        if ext in IMAGE_EXTS:
            n_img += move_file(f, img_dir, dry_run)
        elif ext in LABEL_EXTS:
            n_lbl += move_file(f, lbl_dir, dry_run)

    print(f"[{src_name} -> {dst_name}] images: {n_img}, labels: {n_lbl}")

    # Make sure the standard folders exist even if a split was empty
    if not dry_run:
        img_dir.mkdir(parents=True, exist_ok=True)
        lbl_dir.mkdir(parents=True, exist_ok=True)


def update_yaml(root: Path, dry_run: bool) -> None:
    yaml_path = root / "data.yaml"
    if not yaml_path.exists():
        print("[warn] data.yaml not found in dataset folder; creating a new one")
        existing = ""
    else:
        existing = yaml_path.read_text(encoding="utf-8")

    # Drop old path/train/val/valid/test entries, keep names, nc, etc.
    kept = [ln for ln in existing.splitlines() if not PATH_KEYS.match(ln)]
    body = "\n".join(kept).strip("\n")
    new_text = YAML_HEADER + ("\n" + body + "\n" if body else "")

    if dry_run:
        print("[dry-run] data.yaml would become:\n" + new_text)
    else:
        yaml_path.write_text(new_text, encoding="utf-8")
        print("[ok] data.yaml updated")


def remove_empty_dirs(path: Path, dry_run: bool) -> bool:
    """Recursively remove empty directories. Returns True if `path` was removed."""
    for child in sorted(path.iterdir()):
        if child.is_dir():
            remove_empty_dirs(child, dry_run)
    if not any(path.iterdir()):
        if not dry_run:
            path.rmdir()
        return True
    return False


def cleanup(root: Path, dry_run: bool) -> None:
    for src_name in SPLITS:
        src_dir = root / src_name
        if not src_dir.is_dir():
            continue
        if dry_run:
            print(f"[dry-run] would remove '{src_name}' if empty after moves")
            continue
        if remove_empty_dirs(src_dir, dry_run):
            print(f"[ok] removed empty folder '{src_name}'")
        else:
            leftovers = [p.name for p in src_dir.rglob("*") if p.is_file()]
            print(f"[warn] '{src_name}' not empty, kept. Leftover files: {leftovers[:10]}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Reorganize dataset into YOLO format.")
    parser.add_argument("root", nargs="?", default=None,
                        help="dataset folder (default: current folder if it contains "
                             "train/valid/test, otherwise ./vip)")
    parser.add_argument("--dry-run", action="store_true", help="show what would happen")
    args = parser.parse_args()

    if args.root:
        root = Path(args.root).resolve()
    elif any((Path.cwd() / s).is_dir() for s in SPLITS):
        root = Path.cwd()  # already running inside the dataset folder
    elif (Path.cwd() / "vip").is_dir():
        root = Path.cwd() / "vip"
    else:
        # Script may be sitting inside the dataset folder but run from elsewhere
        root = Path(__file__).resolve().parent

    if not root.is_dir() or not any((root / s).is_dir() for s in SPLITS):
        raise SystemExit(f"No train/valid/test folders found in: {root}\n"
                         f"Pass the dataset path explicitly, e.g. python {Path(__file__).name} path/to/vip")
    print(f"Using dataset folder: {root}")

    for src_name, dst_name in SPLITS.items():
        process_split(root, src_name, dst_name, args.dry_run)

    update_yaml(root, args.dry_run)
    cleanup(root, args.dry_run)
    print("Done." if not args.dry_run else "Dry run complete, no changes made.")


if __name__ == "__main__":
    main()
