"""Sinh assets/content/grade1.json … grade5.json.

Sửa chương trình ở đây rồi chạy:  python3 tool/build_content.py
Thứ tự và tên chủ đề theo SGK Toán Kết nối tri thức với cuộc sống (sgkOrder = số thứ tự chủ đề trong sách):
- Toán 1: 10 chủ đề (5 = Ôn tập học kì I, 10 = Ôn tập cuối năm)
- Toán 2: 14 chủ đề (7 = Ôn tập học kì I, 14 = Ôn tập cuối năm)
- Toán 3: 16 chủ đề (7 = Ôn tập học kì I, 16 = Ôn tập cuối năm)
- Toán 4: 13 chủ đề (7 = Ôn tập học kì I, 13 = Ôn tập cuối năm)
- Toán 5: 12 chủ đề (6 = Ôn tập học kì I, 12 = Ôn tập cuối năm)
Đã đối chiếu với kế hoạch dạy học Toán 1, Toán 2 bộ Kết nối tri thức (hoatieu.vn) ngày 29/10/2026.
"""
import json, os

TIMES = [15, 12, 10, 8, 6]

# Bài chạm đáp án phải giữ tay 3 giây rồi mới chấm, nên cộng thêm thời gian cho mỗi câu.
HOLD_BONUS = {"balloon": 4, "shape_hunt": 4}

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
        ("count_objects", "balloon", 2, {"max": 10}),
        ("skip_count", "jump_count", 1, {"steps": [1], "format": "jump", "minJumps": 3, "maxJumps": 6}, 30),
        ("compare", "sides", 2, {"max": 10, "format": "side", "ask": "mixed"}),
        ("compare", "balloon", 3, {"max": 10, "format": "sign"}),
        ("split_number", "balloon", 3, {"max": 10, "ask": "mixed"}, 8),
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


# ------------------------------------------------------------------ Lớp 3 (16 chủ đề)
grade3 = {"grade": 3, "title": "Lớp 3", "topics": [
    topic("g3-on-tap", "Ôn tập và bổ sung", 1, "numbers", [
        ("compare", "balloon", 3, {"max": 1000, "format": "sign"}),
        ("add_sub", "balloon", 3, {"max": 1000, "ops": ["+", "-"], "carry": "allowed"}, 15),
        ("find_unknown", "balloon", 3, {"ops": ["+", "-"], "max": 100}, 15),
        ("mul_div", "balloon", 3, {"tables": [2, 3, 4, 5], "ops": ["×", ":"]}),
        ("find_unknown", "balloon", 4, {"ops": ["×", ":"], "tables": [2, 3, 4, 5]}, 12),
    ]),
    topic("g3-bang-nhan-chia", "Bảng nhân, bảng chia", 2, "mul_div", [
        ("skip_count", "jump_count", 1, {"steps": [3, 4, 6], "format": "jump", "minJumps": 3, "maxJumps": 6}, 30),
        ("mul_div", "balloon", 3, {"tables": [6, 7], "ops": ["×", ":"]}),
        ("mul_div", "balloon", 3, {"tables": [8, 9], "ops": ["×", ":"]}),
        ("times", "balloon", 3, {"kinds": ["part"], "tables": [2, 3, 4, 5, 6, 7, 8, 9]}, 15),
        ("find_unknown", "balloon", 4, {"ops": ["×", ":"], "tables": [6, 7, 8, 9]}, 12),
    ]),
    topic("g3-hinh-phang-khoi", "Làm quen với hình phẳng, hình khối", 3, "shapes", [
        ("geo", "balloon", 3, {"kinds": ["midpoint"]}, 20),
        ("geo", "balloon", 3, {"kinds": ["circle_parts"]}, 15),
        ("geo", "balloon", 3, {"kinds": ["radius_diameter"]}, 15),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["angle_right", "angle_acute", "angle_obtuse"]}, 12),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["triangle", "quadrilateral", "square", "rectangle", "cube", "cuboid"]}, 10),
    ]),
    topic("g3-nhan-chia-100", "Phép nhân, phép chia trong phạm vi 100", 4, "mul_div", [
        ("mul_div_big", "balloon", 3, {"aDigits": 2, "bDigits": 1, "ops": ["×"], "max": 100}, 15),
        ("times", "balloon", 3, {"kinds": ["up", "down"]}, 15),
        ("mul_div_big", "sides", 2, {"format": "exact_or_not", "aDigits": 2}, 15),
        ("mul_div_big", "balloon", 3, {"aDigits": 2, "bDigits": 1, "ops": [":"], "remainder": True}, 15),
        ("story", "balloon", 4, {"kinds": ["two_step"]}, 25),
    ]),
    topic("g3-don-vi-do", "Một số đơn vị đo độ dài, khối lượng, dung tích, nhiệt độ", 5, "measure", [
        ("unit_choose", "balloon", 3, {"ask": "unit", "units": ["mm", "cm", "m", "g", "kg", "ml", "l"]}, 15),
        ("unit_convert", "balloon", 3, {"quantities": ["length"], "units": ["mm", "cm", "dm", "m"]}, 15),
        ("unit_convert", "balloon", 3, {"quantities": ["mass", "capacity"], "units": ["g", "kg", "ml", "l"]}, 15),
        ("temperature", "balloon", 3, {"kinds": ["read"]}, 12),
        ("temperature", "balloon", 4, {"kinds": ["read", "fact"]}, 10),
    ]),
    topic("g3-nhan-chia-1000", "Phép nhân, phép chia trong phạm vi 1000", 6, "mul_div", [
        ("mul_div_big", "balloon", 3, {"aDigits": 3, "bDigits": 1, "ops": ["×"], "max": 1000}, 15),
        ("mul_div_big", "balloon", 3, {"aDigits": 3, "bDigits": 1, "ops": [":"]}, 15),
        ("expression", "balloon", 3, {"kinds": ["mix"]}, 15),
        ("expression", "balloon", 4, {"kinds": ["paren"]}, 15),
        ("times", "number_line", 3, {"kinds": ["how_many"]}, 15),
    ]),
    topic("g3-on-tap-hk1", "Ôn tập học kì I", 7, "review", [
        ("mul_div", "balloon", 3, {"tables": [2, 3, 4, 5, 6, 7, 8, 9], "ops": ["×", ":"]}, 12),
        ("mul_div_big", "balloon", 3, {"aDigits": 2, "bDigits": 1, "ops": ["×", ":"], "max": 1000}, 15),
        ("geo", "balloon", 3, {"kinds": ["midpoint", "radius_diameter"]}, 15),
        ("unit_convert", "balloon", 3, {"quantities": ["length", "mass", "capacity"], "units": ["mm", "cm", "dm", "m", "g", "kg", "ml", "l"]}, 12),
        ("expression", "balloon", 4, {"kinds": ["mix", "paren"]}, 12),
    ]),
    topic("g3-so-den-10000", "Các số đến 10 000", 8, "numbers", [
        ("digits", "balloon", 3, {"digits": [4], "kinds": ["write", "expand"]}, 15),
        ("digits", "balloon", 3, {"digits": [4], "kinds": ["value", "place"]}, 15),
        ("compare", "sides", 2, {"max": 10000, "format": "side", "ask": "mixed"}),
        ("rounding", "number_line", 3, {"to": ["tens", "hundreds"], "digits": [4]}, 15),
        ("roman", "balloon", 4, {"max": 20, "kinds": ["to_number", "to_roman"]}, 12),
    ]),
    topic("g3-chu-vi-dien-tich", "Chu vi, diện tích một số hình phẳng", 9, "shapes", [
        ("perimeter_area", "balloon", 3, {"kinds": ["triangle_perimeter", "quad_perimeter"]}, 20),
        ("perimeter_area", "balloon", 3, {"kinds": ["rect_perimeter", "square_perimeter"]}, 20),
        ("perimeter_area", "balloon", 3, {"kinds": ["rect_area", "square_area"], "maxSide": 9}, 20),
        ("perimeter_area", "balloon", 4, {"kinds": ["rect_perimeter", "square_perimeter", "rect_area", "square_area"]}, 15),
        ("perimeter_area", "balloon", 4, {"kinds": ["rect_perimeter", "square_perimeter", "rect_area", "square_area", "triangle_perimeter"]}, 12),
    ]),
    topic("g3-tinh-10000", "Cộng, trừ, nhân, chia trong phạm vi 10 000", 10, "add_sub", [
        ("add_sub", "balloon", 3, {"max": 10000, "min": 1000, "ops": ["+"], "carry": "any"}, 15),
        ("add_sub", "balloon", 3, {"max": 10000, "min": 1000, "ops": ["-"], "carry": "any"}, 15),
        ("mul_div_big", "balloon", 3, {"aDigits": 4, "bDigits": 1, "ops": ["×"], "max": 10000}, 15),
        ("mul_div_big", "balloon", 4, {"aDigits": 4, "bDigits": 1, "ops": [":"]}, 15),
        ("add_sub", "sides", 2, {"max": 10000, "min": 1000, "ops": ["+", "-"], "carry": "any", "format": "true_false"}, 12),
    ]),
    topic("g3-so-den-100000", "Các số đến 100 000", 11, "numbers", [
        ("digits", "balloon", 3, {"digits": [5], "kinds": ["write", "expand"]}, 15),
        ("digits", "balloon", 3, {"digits": [5], "kinds": ["value", "place"]}, 15),
        ("compare", "balloon", 3, {"max": 100000, "format": "sign"}, 12),
        ("rounding", "number_line", 3, {"to": ["thousands", "ten_thousands"], "digits": [5]}, 15),
        ("order_numbers", "balloon", 4, {"max": 100000, "count": 4, "ask": "mixed"}, 12),
    ]),
    topic("g3-cong-tru-100000", "Cộng, trừ trong phạm vi 100 000", 12, "add_sub", [
        ("add_sub", "balloon", 3, {"max": 100000, "min": 10000, "ops": ["+"], "carry": "any"}, 15),
        ("add_sub", "balloon", 3, {"max": 100000, "min": 10000, "ops": ["-"], "carry": "any"}, 15),
        ("add_sub", "sides", 2, {"max": 100000, "min": 10000, "ops": ["+", "-"], "carry": "any", "format": "true_false"}, 12),
        ("word_problem", "balloon", 4, {"max": 100000, "kinds": ["add", "sub", "more", "less"]}, 20),
        ("add_sub", "balloon", 4, {"max": 100000, "ops": ["+", "-"], "terms": 3, "carry": "any", "round": "hundreds"}, 15),
    ]),
    topic("g3-gio-thang-tien", "Xem đồng hồ. Tháng – năm. Tiền Việt Nam", 13, "time", [
        ("time", "balloon", 3, {"ask": ["read"], "minutes": [5, 10, 20, 25, 35, 40, 50, 55]}, 15),
        ("time", "human_clock", 1, {"ask": ["pose"], "minutes": [0, 15, 30]}, 20),
        ("time_calc", "balloon", 3, {"kinds": ["elapsed"]}, 20),
        ("money_sum", "balloon", 3, {"kinds": ["sum"], "notes": [1000, 2000, 5000, 10000, 20000, 50000]}, 15),
        ("money_sum", "balloon", 4, {"kinds": ["sum", "change"]}, 15),
    ]),
    topic("g3-nhan-chia-100000", "Nhân, chia trong phạm vi 100 000", 14, "mul_div", [
        ("mul_div_big", "balloon", 3, {"aDigits": 4, "bDigits": 1, "ops": ["×"], "max": 100000}, 15),
        ("mul_div_big", "balloon", 3, {"aDigits": 5, "bDigits": 1, "ops": [":"]}, 15),
        ("mul_div_big", "balloon", 3, {"aDigits": 4, "bDigits": 1, "ops": [":"], "remainder": True}, 15),
        ("expression", "balloon", 4, {"kinds": ["mix", "paren"]}, 15),
        ("story", "balloon", 4, {"kinds": ["two_step"]}, 25),
    ]),
    topic("g3-thong-ke", "Làm quen với yếu tố thống kê, xác suất", 15, "stats", [
        ("data", "balloon", 3, {"kinds": ["table"]}, 15),
        ("likelihood", "balloon", 3, {}, 15),
        ("data", "balloon", 3, {"kinds": ["table"]}, 12),
        ("data", "balloon", 4, {"kinds": ["table"]}, 12),
        ("likelihood", "balloon", 3, {}, 10),
    ]),
    topic("g3-on-tap-cuoi-nam", "Ôn tập cuối năm", 16, "review", [
        ("digits", "balloon", 3, {"digits": [4, 5], "kinds": ["write", "value", "place", "expand"]}, 12),
        ("add_sub", "balloon", 4, {"max": 100000, "min": 1000, "ops": ["+", "-"], "carry": "any"}, 12),
        ("mul_div_big", "balloon", 4, {"aDigits": 4, "bDigits": 1, "ops": ["×", ":"], "max": 100000}, 12),
        ("perimeter_area", "balloon", 4, {"kinds": ["rect_perimeter", "square_perimeter", "rect_area", "square_area"]}, 12),
        ("money_sum", "balloon", 4, {"kinds": ["sum", "change"]}, 12),
    ]),
]}

# ------------------------------------------------------------------ Lớp 4 (13 chủ đề)
grade4 = {"grade": 4, "title": "Lớp 4", "topics": [
    topic("g4-on-tap", "Ôn tập và bổ sung", 1, "numbers", [
        ("digits", "balloon", 3, {"digits": [5], "kinds": ["write", "value"]}, 15),
        ("even_odd", "sides", 2, {"format": "side", "max": 100000}),
        ("even_odd", "balloon", 3, {"format": "pick", "max": 10000}),
        ("expression", "balloon", 3, {"kinds": ["letter"]}, 15),
        ("story", "balloon", 4, {"kinds": ["two_step"]}, 25),
    ]),
    topic("g4-goc", "Góc và đơn vị đo góc", 2, "angle", [
        ("geo", "arm_angle", 1, {"kinds": ["arm_angle"], "angles": ["right", "straight"]}, 20),
        ("geo", "balloon", 3, {"kinds": ["angle_type"], "angles": ["acute", "right", "obtuse"]}, 12),
        ("geo", "balloon", 3, {"kinds": ["angle_measure"]}, 15),
        ("geo", "arm_angle", 1, {"kinds": ["arm_angle"]}, 20),
        ("geo", "balloon", 4, {"kinds": ["angle_type"]}, 10),
    ]),
    topic("g4-so-nhieu-chu-so", "Số có nhiều chữ số", 3, "numbers", [
        ("digits", "balloon", 3, {"digits": [6, 7], "kinds": ["write"]}, 15),
        ("digits", "balloon", 3, {"digits": [6, 7, 8, 9], "kinds": ["value", "place"]}, 15),
        ("compare", "balloon", 3, {"max": 1000000000, "format": "sign"}, 12),
        ("rounding", "number_line", 3, {"to": ["hundred_thousands"], "digits": [6, 7]}, 15),
        ("order_numbers", "balloon", 4, {"max": 10000000, "count": 4, "ask": "mixed"}, 12),
    ]),
    topic("g4-dai-luong", "Một số đơn vị đo đại lượng", 4, "measure", [
        ("unit_convert", "balloon", 3, {"quantities": ["mass"], "units": ["kg", "yến", "tạ", "tấn"]}, 15),
        ("unit_convert", "balloon", 3, {"quantities": ["area"], "units": ["mm²", "cm²", "dm²", "m²"], "maxRatio": 10000}, 15),
        ("unit_convert", "balloon", 3, {"quantities": ["time", "years"], "units": ["giây", "phút", "giờ", "năm", "thế kỉ"]}, 15),
        ("time_calc", "balloon", 3, {"kinds": ["century"]}, 12),
        ("unit_convert", "balloon", 4, {"quantities": ["mass", "area", "time"], "units": ["kg", "yến", "tạ", "tấn", "cm²", "dm²", "m²", "giây", "phút", "giờ"], "maxRatio": 10000, "compound": True}, 15),
    ]),
    topic("g4-cong-tru", "Phép cộng, phép trừ", 5, "add_sub", [
        ("add_sub", "balloon", 3, {"max": 1000000, "min": 100000, "ops": ["+"], "carry": "any"}, 15),
        ("add_sub", "balloon", 3, {"max": 1000000, "min": 100000, "ops": ["-"], "carry": "any"}, 15),
        ("expression", "balloon", 3, {"kinds": ["quick"]}, 15),
        ("story", "balloon", 4, {"kinds": ["sum_diff"]}, 25),
        ("add_sub", "sides", 2, {"max": 1000000, "min": 100000, "ops": ["+", "-"], "carry": "any", "format": "true_false"}, 12),
    ]),
    topic("g4-vuong-goc-song-song", "Đường thẳng vuông góc, đường thẳng song song", 6, "shapes", [
        ("shape_identify", "shape_hunt", 2, {"shapes": ["lines_perpendicular", "lines_parallel"]}, 15),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["lines_perpendicular", "lines_parallel", "lines_intersect"]}, 12),
        ("geo", "arm_angle", 1, {"kinds": ["arm_angle"], "angles": ["right", "straight"]}, 20),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["parallelogram", "rhombus", "rectangle", "square"]}, 12),
        ("shape_identify", "shape_hunt", 4, {"shapes": ["parallelogram", "rhombus", "rectangle", "square", "quadrilateral"]}, 10),
    ]),
    topic("g4-on-tap-hk1", "Ôn tập học kì I", 7, "review", [
        ("digits", "balloon", 3, {"digits": [6, 7, 8, 9], "kinds": ["value", "place"]}, 12),
        ("rounding", "balloon", 3, {"to": ["thousands", "ten_thousands", "hundred_thousands"], "digits": [6]}, 12),
        ("unit_convert", "balloon", 3, {"quantities": ["mass", "area"], "units": ["kg", "yến", "tạ", "tấn", "cm²", "dm²", "m²"], "maxRatio": 10000}, 12),
        ("add_sub", "balloon", 4, {"max": 1000000, "min": 100000, "ops": ["+", "-"], "carry": "any"}, 12),
        ("geo", "balloon", 4, {"kinds": ["angle_type", "angle_measure"]}, 12),
    ]),
    topic("g4-nhan-chia", "Phép nhân và phép chia", 8, "mul_div", [
        ("mul_div_big", "balloon", 3, {"aDigits": 4, "bDigits": 1, "ops": ["×", ":"], "max": 1000000}, 15),
        ("mul_div_big", "balloon", 3, {"aDigits": 3, "bValues": [10, 100, 1000], "ops": ["×"], "max": 1000000}, 12),
        ("mul_div_big", "balloon", 3, {"aDigits": 2, "bDigits": 2, "ops": ["×"], "max": 10000}, 20),
        ("mul_div_big", "balloon", 4, {"aDigits": 4, "bDigits": 2, "ops": [":"]}, 20),
        ("story", "balloon", 4, {"kinds": ["average", "unit_rate"]}, 25),
    ]),
    topic("g4-thong-ke", "Làm quen với yếu tố thống kê, xác suất", 9, "stats", [
        ("data", "balloon", 3, {"kinds": ["bar"]}, 15),
        ("data", "balloon", 3, {"kinds": ["series"]}, 20),
        ("data", "balloon", 3, {"kinds": ["coin"]}, 15),
        ("data", "balloon", 4, {"kinds": ["bar"]}, 12),
        ("data", "balloon", 4, {"kinds": ["bar", "series", "coin"]}, 12),
    ]),
    topic("g4-phan-so", "Phân số", 10, "fraction", [
        ("fraction", "balloon", 3, {"kinds": ["picture"]}, 15),
        ("fraction", "balloon", 3, {"kinds": ["reduce", "equivalent"]}, 15),
        ("fraction", "balloon", 3, {"kinds": ["compare"]}, 15),
        ("fraction", "number_line", 3, {"kinds": ["of_number"]}, 20),
        ("fraction", "balloon", 4, {"kinds": ["reduce", "equivalent", "common_den", "compare"]}, 12),
    ]),
    topic("g4-cong-tru-phan-so", "Phép cộng, phép trừ phân số", 11, "fraction", [
        ("fraction", "balloon", 3, {"kinds": ["add"], "sameDen": True}, 15),
        ("fraction", "balloon", 3, {"kinds": ["sub"], "sameDen": True}, 15),
        ("fraction", "balloon", 3, {"kinds": ["add"], "maxDen": 8}, 20),
        ("fraction", "balloon", 4, {"kinds": ["sub"], "maxDen": 8}, 20),
        ("fraction", "balloon", 4, {"kinds": ["add", "sub"], "maxDen": 9}, 15),
    ]),
    topic("g4-nhan-chia-phan-so", "Phép nhân, phép chia phân số", 12, "fraction", [
        ("fraction", "balloon", 3, {"kinds": ["mul"], "maxDen": 7}, 15),
        ("fraction", "balloon", 3, {"kinds": ["div"], "maxDen": 7}, 15),
        ("fraction", "balloon", 3, {"kinds": ["of_number"]}, 15),
        ("fraction", "balloon", 4, {"kinds": ["mul", "div"], "maxDen": 9}, 15),
        ("fraction", "number_line", 3, {"kinds": ["of_number"]}, 15),
    ]),
    topic("g4-on-tap-cuoi-nam", "Ôn tập cuối năm", 13, "review", [
        ("digits", "balloon", 3, {"digits": [6, 7, 8, 9], "kinds": ["value", "place", "write"]}, 12),
        ("mul_div_big", "balloon", 4, {"aDigits": 3, "bDigits": 2, "ops": ["×", ":"], "max": 100000}, 15),
        ("fraction", "balloon", 4, {"kinds": ["add", "sub", "mul", "div"]}, 15),
        ("geo", "balloon", 4, {"kinds": ["angle_type", "angle_measure"]}, 10),
        ("data", "balloon", 4, {"kinds": ["bar", "series"]}, 12),
    ]),
]}

# ------------------------------------------------------------------ Lớp 5 (12 chủ đề)
grade5 = {"grade": 5, "title": "Lớp 5", "topics": [
    topic("g5-on-tap", "Ôn tập và bổ sung", 1, "fraction", [
        ("fraction", "balloon", 3, {"kinds": ["decimal_fraction"]}, 12),
        ("fraction", "balloon", 3, {"kinds": ["compare"]}, 12),
        ("fraction", "balloon", 3, {"kinds": ["add", "sub"]}, 20),
        ("fraction", "balloon", 3, {"kinds": ["mixed"]}, 15),
        ("fraction", "balloon", 4, {"kinds": ["mul", "div", "mixed", "add", "sub"]}, 15),
    ]),
    topic("g5-so-thap-phan", "Số thập phân", 2, "decimal", [
        ("decimal", "balloon", 3, {"kinds": ["structure", "from_fraction"]}, 15),
        ("decimal", "balloon", 3, {"kinds": ["place"]}, 15),
        ("decimal", "balloon", 3, {"kinds": ["compare", "max"]}, 15),
        ("decimal", "balloon", 4, {"kinds": ["unit"]}, 15),
        ("decimal", "number_line", 3, {"kinds": ["round"]}, 15),
    ]),
    topic("g5-dien-tich", "Một số đơn vị đo diện tích", 3, "measure", [
        ("unit_convert", "balloon", 3, {"quantities": ["area"], "units": ["cm²", "dm²", "m²"], "maxRatio": 10000}, 15),
        ("unit_convert", "balloon", 3, {"quantities": ["area"], "units": ["m²", "ha", "km²"], "maxRatio": 10000}, 15),
        ("unit_convert", "balloon", 3, {"quantities": ["area"], "units": ["dm²", "m²", "ha", "km²"], "maxRatio": 10000, "compound": True}, 15),
        ("unit_convert", "number_line", 3, {"quantities": ["area"], "units": ["m²", "ha", "km²"], "maxRatio": 10000}, 15),
        ("unit_convert", "balloon", 4, {"quantities": ["area"], "maxRatio": 10000, "compound": True}, 12),
    ]),
    topic("g5-tinh-thap-phan", "Các phép tính với số thập phân", 4, "decimal", [
        ("decimal", "balloon", 3, {"kinds": ["add", "sub"]}, 15),
        ("decimal", "balloon", 3, {"kinds": ["mul"]}, 15),
        ("decimal", "balloon", 3, {"kinds": ["div"]}, 15),
        ("decimal", "balloon", 3, {"kinds": ["shift"]}, 12),
        ("decimal", "balloon", 4, {"kinds": ["add", "sub", "mul", "div", "shift"]}, 12),
    ]),
    topic("g5-hinh-phang", "Một số hình phẳng. Chu vi và diện tích", 5, "shapes", [
        ("perimeter_area", "balloon", 3, {"kinds": ["triangle_area"]}, 20),
        ("perimeter_area", "balloon", 3, {"kinds": ["trapezoid_area"]}, 20),
        ("perimeter_area", "balloon", 3, {"kinds": ["circle_c"]}, 20),
        ("perimeter_area", "balloon", 3, {"kinds": ["circle_area"]}, 20),
        ("perimeter_area", "balloon", 4, {"kinds": ["triangle_area", "trapezoid_area", "circle_c", "circle_area"]}, 15),
    ]),
    topic("g5-on-tap-hk1", "Ôn tập học kì I", 6, "review", [
        ("decimal", "balloon", 3, {"kinds": ["compare", "round"]}, 12),
        ("decimal", "balloon", 3, {"kinds": ["add", "sub", "mul"]}, 15),
        ("decimal", "balloon", 3, {"kinds": ["unit"]}, 12),
        ("perimeter_area", "balloon", 4, {"kinds": ["triangle_area", "trapezoid_area"]}, 15),
        ("fraction", "balloon", 4, {"kinds": ["mixed", "decimal_fraction"]}, 12),
    ]),
    topic("g5-ti-so", "Tỉ số và các bài toán liên quan", 7, "percent", [
        ("percent", "balloon", 3, {"kinds": ["ratio", "ratio_percent"]}, 15),
        ("percent", "balloon", 3, {"kinds": ["of", "whole"]}, 15),
        ("percent", "balloon", 3, {"kinds": ["map_scale"]}, 20),
        ("story", "balloon", 4, {"kinds": ["sum_ratio", "diff_ratio"]}, 25),
        ("percent", "number_line", 3, {"kinds": ["of"]}, 15),
    ]),
    topic("g5-the-tich", "Thể tích. Đơn vị đo thể tích", 8, "measure", [
        ("perimeter_area", "balloon", 3, {"kinds": ["cube_volume"], "maxSide": 9}, 15),
        ("perimeter_area", "balloon", 3, {"kinds": ["box_volume"], "maxSide": 9}, 20),
        ("unit_convert", "balloon", 3, {"quantities": ["volume"]}, 15),
        ("unit_convert", "balloon", 4, {"quantities": ["volume"], "compound": True}, 15),
        ("perimeter_area", "balloon", 4, {"kinds": ["box_volume", "cube_volume"], "units": ["cm", "dm", "m"]}, 15),
    ]),
    topic("g5-dien-tich-the-tich", "Diện tích và thể tích của một số hình khối", 9, "shapes", [
        ("perimeter_area", "balloon", 3, {"kinds": ["box_lateral"], "maxSide": 9}, 20),
        ("perimeter_area", "balloon", 3, {"kinds": ["box_total"], "maxSide": 9}, 25),
        ("perimeter_area", "balloon", 3, {"kinds": ["cube_lateral", "cube_total"], "maxSide": 9}, 20),
        ("shape_identify", "shape_hunt", 3, {"shapes": ["cube", "cuboid", "cylinder", "sphere"]}, 10),
        ("perimeter_area", "balloon", 4, {"kinds": ["box_lateral", "box_total", "cube_lateral", "cube_total", "box_volume", "cube_volume"], "maxSide": 9}, 20),
    ]),
    topic("g5-thoi-gian-van-toc", "Số đo thời gian, vận tốc, chuyển động đều", 10, "time", [
        ("time_calc", "balloon", 3, {"kinds": ["add", "sub"]}, 20),
        ("time_calc", "balloon", 3, {"kinds": ["mul", "hours_decimal"]}, 20),
        ("motion", "balloon", 3, {"kinds": ["speed"]}, 20),
        ("motion", "balloon", 3, {"kinds": ["distance", "time"]}, 20),
        ("motion", "balloon", 4, {"kinds": ["speed", "distance", "time"]}, 15),
    ]),
    topic("g5-thong-ke", "Một số yếu tố thống kê và xác suất", 11, "stats", [
        ("data", "balloon", 3, {"kinds": ["pie"]}, 20),
        ("data", "balloon", 3, {"kinds": ["coin_ratio"]}, 20),
        ("data", "balloon", 3, {"kinds": ["bar"]}, 15),
        ("data", "balloon", 4, {"kinds": ["pie"]}, 15),
        ("data", "balloon", 4, {"kinds": ["pie", "coin_ratio", "series"]}, 15),
    ]),
    topic("g5-on-tap-cuoi-nam", "Ôn tập cuối năm", 12, "review", [
        ("decimal", "balloon", 3, {"kinds": ["add", "sub", "mul", "div"]}, 15),
        ("percent", "balloon", 3, {"kinds": ["of", "ratio_percent"]}, 15),
        ("perimeter_area", "balloon", 4, {"kinds": ["box_volume", "cube_volume", "circle_area", "triangle_area"]}, 15),
        ("motion", "balloon", 4, {"kinds": ["speed", "distance", "time"]}, 15),
        ("fraction", "balloon", 4, {"kinds": ["add", "sub", "mul", "div"]}, 15),
    ]),
]}

# Game vận động mới: đổi mini game của một số level (giữ nguyên bộ sinh câu hỏi), rải đều các lớp và độ khó.
# Mỗi mini game đòi hỏi: star_catch / hop_tiles ≥ 2 đáp án; tintin_says đúng 3 đáp án; touch_order câu xếp thứ tự;
# balance / run_race / squat_gate đúng 2 đáp án; clap_count câu đếm nhảy.
NEW_GAMES = {
    "star_catch": ["g1-so-den-100:2", "g1-cong-tru-10:2", "g2-cong-tru-20:2", "g2-so-den-1000:3",
                   "g3-tinh-10000:1", "g4-cong-tru:2", "g5-so-thap-phan:2"],
    "hop_tiles": ["g1-cong-tru-100:2", "g1-on-tap-hk1:1", "g2-cong-tru-100:2", "g3-nhan-chia-100:1",
                  "g4-nhan-chia:1", "g5-ti-so:1"],
    "tintin_says": ["g1-on-tap-hk1:2", "g2-on-tap:2", "g2-nhan-chia:3", "g3-on-tap:2", "g4-on-tap:3", "g5-on-tap:2"],
    "touch_order": ["g1-so-den-100:5", "g2-on-tap:4", "g2-so-den-1000:5", "g3-so-den-100000:5"],
    "balance": ["g1-so-den-10:3", "g1-do-dai:1", "g1-do-dai:3", "g1-so-den-100:4", "g3-so-den-10000:3"],
    "run_race": ["g1-do-dai:2", "g1-do-dai:4", "g2-khoi-luong-dung-tich:1", "g3-nhan-chia-100:3", "g3-cong-tru-100000:3"],
    "squat_gate": ["g1-cong-tru-10:3", "g2-cong-tru-20:3", "g2-cong-tru-100:4", "g4-on-tap:2", "g4-cong-tru:5"],
    "clap_count": ["g2-nhan-chia:1", "g3-bang-nhan-chia:1"],
}
_levels = {(t["id"], l["level"]): l for g in (grade1, grade2, grade3, grade4, grade5) for t in g["topics"] for l in t["levels"]}
for _game, _where in NEW_GAMES.items():
    for _w in _where:
        _tid, _n = _w.rsplit(":", 1)
        _l = _levels[(_tid, int(_n))]
        _l["miniGame"] = _game
        if _game == "touch_order":
            _l["params"] = {**_l["params"], "ask": "order"}
# Dạng bài ít biến thể thì hỏi ít câu hơn (≤ 2 lần mỗi biến thể) để bé không gặp một câu lặp đi lặp lại.
FEW_VARIANTS = {
    "g1-so-den-10:2": 8, "g1-hinh-khoi-vi-tri:1": 4, "g1-hinh-phang:4": 8, "g1-hinh-phang:5": 8, "g1-hinh-khoi-vi-tri:2": 6, "g1-hinh-khoi-vi-tri:3": 4,
    "g2-hinh-khoi:1": 4, "g2-hinh-khoi:4": 8, "g2-hinh-khoi:5": 8, "g2-hinh-phang:1": 6, "g2-do-dai-tien:1": 8,
    "g2-do-dai-tien:3": 6, "g3-hinh-phang-khoi:2": 6, "g3-hinh-phang-khoi:4": 6, "g4-goc:2": 6, "g4-goc:5": 8, "g4-vuong-goc-song-song:2": 6,
    "g4-goc:1": 4, "g4-goc:4": 8, "g4-vuong-goc-song-song:1": 4, "g4-vuong-goc-song-song:3": 4,
}
for _w, _q in FEW_VARIANTS.items():
    _tid, _n = _w.rsplit(":", 1)
    _levels[(_tid, int(_n))]["questions"] = _q
for _l in _levels.values():
    _l["secondsPerQuestion"] += HOLD_BONUS.get(_l["miniGame"], 0)

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "content")
for name, g in (("grade1.json", grade1), ("grade2.json", grade2), ("grade3.json", grade3), ("grade4.json", grade4), ("grade5.json", grade5)):
    with open(os.path.join(root, name), "w", encoding="utf-8") as f:
        json.dump(g, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(name, len(g["topics"]), "chủ đề,", sum(len(t["levels"]) for t in g["topics"]), "level")
