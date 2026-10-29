"""Sinh assets/content/grade1.json và grade2.json.

Sửa chương trình ở đây rồi chạy:  python3 tool/build_content.py
Thứ tự và tên chủ đề theo SGK Toán Kết nối tri thức với cuộc sống (sgkOrder = số thứ tự chủ đề trong sách):
- Toán 1: 10 chủ đề (5 = Ôn tập học kì I, 10 = Ôn tập cuối năm)
- Toán 2: 14 chủ đề (7 = Ôn tập học kì I, 14 = Ôn tập cuối năm)
Đã đối chiếu với kế hoạch dạy học Toán 1, Toán 2 bộ Kết nối tri thức (hoatieu.vn) ngày 29/10/2026.
"""
import json, os

TIMES = [15, 12, 10, 8, 6]

def lv(i, gen, game, answers, params=None, seconds=None, questions=10):
    return {
        "level": i + 1,
        "questions": questions,
        "secondsPerQuestion": seconds if seconds is not None else TIMES[i],
        "generator": gen,
        "params": params or {},
        "answers": answers,
        "miniGame": game,
    }

def topic(tid, title, order, icon, levels):
    return {"id": tid, "title": title, "sgkOrder": order, "icon": icon,
            "levels": [lv(i, *l) for i, l in enumerate(levels)]}

grade1 = {"grade": 1, "title": "Lớp 1", "topics": [
    topic("g1-so-den-10", "Các số từ 0 đến 10", 1, "numbers", [
        ("count_objects", "balloon", 2, {"max": 5}),
        ("count_objects", "balloon", 3, {"max": 10}),
        ("skip_count", "jump_count", 1, {"steps": [1], "format": "jump", "minJumps": 3, "maxJumps": 6}, 30),
        ("compare", "sides", 2, {"max": 10, "format": "side", "ask": "mixed"}),
        ("compare", "balloon", 3, {"max": 10, "format": "sign"}),
    ]),
    topic("g1-hinh-phang", "Làm quen với một số hình phẳng", 2, "shapes", [
        ("shape_identify", "shape_hunt", 2, {"shapes": ["square", "circle", "triangle", "rectangle"]}, 15),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["square", "circle", "triangle", "rectangle"]}, 12),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["square", "circle", "triangle", "rectangle"]}, 10),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["square", "circle", "triangle", "rectangle"]}, 10),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["square", "circle", "triangle", "rectangle"]}, 8),
    ]),
    topic("g1-cong-tru-10", "Phép cộng, phép trừ trong phạm vi 10", 3, "add_sub", [
        ("add_sub", "balloon", 2, {"max": 5, "ops": ["+"]}),
        ("add_sub", "balloon", 3, {"max": 10, "ops": ["+", "-"]}),
        ("add_sub", "sides", 2, {"max": 10, "ops": ["+", "-"], "format": "true_false"}),
        ("word_problem", "balloon", 3, {"max": 10, "kinds": ["add", "sub"], "ask": "mixed"}, 20),
        ("add_sub", "balloon", 4, {"max": 10, "ops": ["+", "-"], "terms": 3}),
    ]),
    topic("g1-hinh-khoi-vi-tri", "Làm quen với một số hình khối", 4, "position", [
        ("shape_identify", "shape_hunt", 2, {"shapes": ["cube", "cuboid"]}, 15),
        ("position", "simon_says", 3, {"types": ["pose"]}, 12),
        ("position", "simon_says", 2, {"types": ["step"]}, 12),
        ("position", "simon_says", 3, {"types": ["touch"], "scenes": ["shelf", "table", "tree", "box"]}, 12),
        ("position", "simon_says", 3, {"types": ["pose", "step", "touch", "compound"], "scenes": ["shelf", "table", "tree", "box"]}, 12),
    ]),
    topic("g1-on-tap-hk1", "Ôn tập học kì I", 5, "review", [
        ("count_objects", "balloon", 3, {"max": 10}),
        ("add_sub", "balloon", 3, {"max": 10, "ops": ["+", "-"]}),
        ("compare", "balloon", 3, {"max": 10, "format": "sign"}),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["square", "circle", "triangle", "rectangle", "cube", "cuboid"]}, 10),
        ("word_problem", "balloon", 3, {"max": 10, "kinds": ["add", "sub"], "ask": "mixed"}, 15),
    ]),
    topic("g1-so-den-100", "Các số đến 100", 6, "numbers", [
        ("count_objects", "balloon", 3, {"max": 20}),
        ("count_objects", "balloon", 3, {"min": 21, "max": 100}, 15),
        ("place_value", "balloon", 3, {"max": 100}),
        ("compare", "sides", 2, {"max": 100, "format": "side", "ask": "mixed"}),
        ("order_numbers", "balloon", 4, {"max": 100, "count": 4, "ask": "mixed"}, 10),
    ]),
    topic("g1-do-dai", "Độ dài và đo độ dài", 7, "measure", [
        ("length_compare", "sides", 2, {"measure": "length"}),
        ("length_compare", "sides", 2, {"measure": "length"}),
        ("length_compare", "sides", 2, {"measure": "length"}),
        ("length_compare", "sides", 2, {"measure": "length"}),
        ("length_compare", "sides", 2, {"measure": "length"}),
    ]),
    topic("g1-cong-tru-100", "Phép cộng, phép trừ (không nhớ) trong phạm vi 100", 8, "add_sub", [
        ("add_sub", "balloon", 2, {"max": 100, "ops": ["+", "-"], "round": "tens"}),
        ("add_sub", "balloon", 3, {"max": 100, "ops": ["+"], "carry": "none"}),
        ("add_sub", "balloon", 3, {"max": 100, "ops": ["-"], "carry": "none"}),
        ("add_sub", "sides", 2, {"max": 100, "ops": ["+", "-"], "carry": "none", "format": "true_false"}),
        ("word_problem", "balloon", 4, {"max": 100, "kinds": ["add", "sub"], "ask": "mixed"}, 15),
    ]),
    topic("g1-thoi-gian", "Thời gian, giờ và lịch", 9, "time", [
        ("time", "balloon", 2, {"ask": ["read"], "minutes": [0]}),
        ("time", "balloon", 3, {"ask": ["read"], "minutes": [0]}),
        ("time", "balloon", 3, {"ask": ["weekday"]}, 12),
        ("time", "human_clock", 1, {"ask": ["pose"], "minutes": [0]}, 20),
        ("time", "balloon", 4, {"ask": ["read", "weekday"], "minutes": [0]}, 8),
    ]),
    topic("g1-on-tap-cuoi-nam", "Ôn tập cuối năm", 10, "review", [
        ("add_sub", "balloon", 3, {"max": 10, "ops": ["+", "-"]}),
        ("add_sub", "balloon", 3, {"max": 100, "ops": ["+", "-"], "carry": "none"}),
        ("order_numbers", "balloon", 4, {"max": 100, "count": 4, "ask": "mixed"}, 10),
        ("time", "balloon", 3, {"ask": ["read", "weekday"], "minutes": [0]}, 10),
        ("word_problem", "balloon", 4, {"max": 100, "kinds": ["add", "sub"], "ask": "mixed"}, 15),
    ]),
]}

grade2 = {"grade": 2, "title": "Lớp 2", "topics": [
    topic("g2-on-tap", "Ôn tập và bổ sung", 1, "numbers", [
        ("neighbors", "balloon", 2, {"max": 100, "ask": "mixed"}),
        ("neighbors", "balloon", 3, {"max": 100, "ask": "number_line", "steps": [1, 10]}),
        ("compare", "balloon", 3, {"max": 100, "format": "sign"}),
        ("order_numbers", "balloon", 4, {"max": 100, "count": 4, "ask": "mixed"}),
        ("add_sub", "balloon", 4, {"max": 100, "ops": ["+", "-"], "carry": "none"}),
    ]),
    topic("g2-cong-tru-20", "Phép cộng, phép trừ trong phạm vi 20", 2, "add_sub", [
        ("add_sub", "balloon", 2, {"max": 20, "ops": ["+"], "carry": "allowed"}),
        ("add_sub", "balloon", 3, {"max": 20, "ops": ["+", "-"], "carry": "allowed"}),
        ("add_sub", "sides", 2, {"max": 20, "ops": ["+", "-"], "carry": "allowed", "format": "true_false"}),
        ("word_problem", "balloon", 3, {"max": 20, "kinds": ["add", "sub", "more", "less"]}, 20),
        ("add_sub", "balloon", 4, {"max": 20, "ops": ["+", "-"], "carry": "required"}),
    ]),
    topic("g2-khoi-luong-dung-tich", "Làm quen với khối lượng, dung tích", 3, "measure", [
        ("length_compare", "sides", 2, {"measure": "weight"}),
        ("unit_choose", "balloon", 3, {"ask": "unit"}, 15),
        ("unit_choose", "balloon", 4, {"ask": "unit"}, 12),
        ("length_compare", "sides", 2, {"measure": "weight"}),
        ("unit_choose", "balloon", 4, {"ask": "mixed"}, 10),
    ]),
    topic("g2-cong-tru-100", "Phép cộng, phép trừ có nhớ trong phạm vi 100", 4, "add_sub", [
        ("add_sub", "balloon", 2, {"max": 100, "ops": ["+", "-"], "round": "tens"}),
        ("add_sub", "balloon", 3, {"max": 100, "ops": ["+"], "carry": "required"}),
        ("add_sub", "balloon", 3, {"max": 100, "ops": ["-"], "carry": "required"}),
        ("add_sub", "sides", 2, {"max": 100, "ops": ["+", "-"], "carry": "allowed", "format": "true_false"}),
        ("word_problem", "balloon", 4, {"max": 100, "kinds": ["add", "sub", "more", "less"], "ask": "mixed"}, 15),
    ]),
    topic("g2-hinh-phang", "Làm quen với hình phẳng", 5, "shapes", [
        ("shape_identify", "shape_hunt", 3, {"shapes": ["segment", "curve", "polyline"]}, 15),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["quadrilateral", "triangle", "circle", "polyline", "segment"]}, 12),
        ("polyline_length", "balloon", 3, {"minSegments": 2, "maxSegments": 2}, 15),
        ("polyline_length", "balloon", 3, {"minSegments": 3, "maxSegments": 3}, 15),
        ("polyline_length", "balloon", 4, {"minSegments": 3, "maxSegments": 4, "maxLength": 15}, 12),
    ]),
    topic("g2-thoi-gian", "Ngày – giờ, giờ – phút, ngày – tháng", 6, "time", [
        ("time", "balloon", 3, {"ask": ["read"], "minutes": [0, 15, 30]}),
        ("time", "balloon", 4, {"ask": ["read"], "minutes": [0, 15, 30]}, 10),
        ("time", "human_clock", 1, {"ask": ["pose"], "minutes": [0, 15, 30]}, 20),
        ("time", "balloon", 3, {"ask": ["month_days"]}, 10),
        ("time", "balloon", 4, {"ask": ["read", "month_days", "weekday"], "minutes": [0, 15, 30]}, 8),
    ]),
    topic("g2-on-tap-hk1", "Ôn tập học kì I", 7, "review", [
        ("add_sub", "balloon", 3, {"max": 20, "ops": ["+", "-"], "carry": "allowed"}),
        ("add_sub", "balloon", 3, {"max": 100, "ops": ["+", "-"], "carry": "allowed"}, 12),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["quadrilateral", "triangle", "circle", "polyline", "segment"]}, 10),
        ("unit_choose", "balloon", 3, {"ask": "unit"}, 12),
        ("time", "balloon", 4, {"ask": ["read", "month_days"], "minutes": [0, 15, 30]}, 10),
    ]),
    topic("g2-nhan-chia", "Phép nhân, phép chia", 8, "mul_div", [
        ("skip_count", "jump_count", 1, {"steps": [2, 5], "format": "jump", "minJumps": 3, "maxJumps": 6}, 30),
        ("skip_count", "balloon", 3, {"steps": [2, 5], "format": "choice"}),
        ("mul_div", "balloon", 3, {"tables": [2, 5], "ops": ["×"]}),
        ("mul_div", "balloon", 4, {"tables": [2, 5], "ops": [":"]}),
        ("mul_div", "balloon", 4, {"tables": [2, 5], "ops": ["×", ":"]}),
    ]),
    topic("g2-hinh-khoi", "Làm quen với hình khối", 9, "shapes", [
        ("shape_identify", "shape_hunt", 2, {"shapes": ["cylinder", "sphere"]}, 15),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["cube", "cuboid", "cylinder", "sphere"]}, 12),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["cube", "cuboid", "cylinder", "sphere"]}, 10),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["cube", "cuboid", "cylinder", "sphere"]}, 10),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["cube", "cuboid", "cylinder", "sphere"]}, 8),
    ]),
    topic("g2-so-den-1000", "Các số trong phạm vi 1000", 10, "numbers", [
        ("place_value", "balloon", 3, {"max": 1000}),
        ("neighbors", "balloon", 3, {"max": 1000, "ask": "mixed", "steps": [1, 10, 100]}),
        ("neighbors", "balloon", 3, {"max": 1000, "ask": "number_line", "steps": [10, 100]}),
        ("compare", "balloon", 3, {"max": 1000, "format": "sign"}),
        ("order_numbers", "balloon", 4, {"max": 1000, "count": 4, "ask": "mixed"}),
    ]),
    topic("g2-do-dai-tien", "Độ dài và đơn vị đo độ dài. Tiền Việt Nam", 11, "money", [
        ("unit_choose", "balloon", 3, {"ask": "convert"}, 15),
        ("unit_choose", "balloon", 3, {"ask": "unit"}, 12),
        ("money_identify", "shape_hunt", 3, {"notes": [1000, 2000, 5000]}, 12),
        ("money_identify", "shape_hunt", 4, {"notes": [1000, 2000, 5000, 10000, 20000, 50000]}, 10),
        ("unit_choose", "balloon", 4, {"ask": "mixed"}, 8),
    ]),
    topic("g2-cong-tru-1000", "Phép cộng, phép trừ trong phạm vi 1000", 12, "add_sub", [
        ("add_sub", "balloon", 2, {"max": 1000, "ops": ["+", "-"], "round": "hundreds"}),
        ("add_sub", "balloon", 3, {"max": 1000, "ops": ["+", "-"], "round": "tens", "carry": "none"}),
        ("add_sub", "balloon", 3, {"max": 1000, "ops": ["+", "-"], "carry": "none"}, 12),
        ("add_sub", "balloon", 4, {"max": 1000, "ops": ["+", "-"], "carry": "allowed"}, 12),
        ("word_problem", "balloon", 4, {"max": 1000, "kinds": ["add", "sub", "more", "less"]}, 15),
    ]),
    topic("g2-thong-ke", "Làm quen với yếu tố thống kê, xác suất", 13, "stats", [
        ("pictograph", "balloon", 3, {"ask": ["count"], "rows": 3}, 15),
        ("pictograph", "balloon", 3, {"ask": ["most", "least"], "rows": 3}, 12),
        ("pictograph", "balloon", 4, {"ask": ["difference"], "rows": 4}, 15),
        ("likelihood", "balloon", 3, {}, 15),
        ("pictograph", "balloon", 4, {"ask": ["count", "most", "least", "difference"], "rows": 4}, 10),
    ]),
    topic("g2-on-tap-cuoi-nam", "Ôn tập cuối năm", 14, "review", [
        ("compare", "balloon", 3, {"max": 1000, "format": "sign"}),
        ("add_sub", "balloon", 4, {"max": 1000, "ops": ["+", "-"], "carry": "allowed"}, 12),
        ("mul_div", "balloon", 4, {"tables": [2, 5], "ops": ["×", ":"]}, 10),
        ("pictograph", "balloon", 3, {"ask": ["count", "most", "least"], "rows": 3}, 12),
        ("likelihood", "balloon", 3, {}, 12),
    ]),
]}

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "content")
for name, g in (("grade1.json", grade1), ("grade2.json", grade2)):
    with open(os.path.join(root, name), "w", encoding="utf-8") as f:
        json.dump(g, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(name, len(g["topics"]), "chủ đề,", sum(len(t["levels"]) for t in g["topics"]), "level")
