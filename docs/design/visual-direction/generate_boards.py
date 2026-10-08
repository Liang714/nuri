#!/usr/bin/env python3
"""Generates the Nuri phone boards from one shared component set (fix round after audit)."""
import os

OUT = os.path.dirname(os.path.abspath(__file__))

# ---------- tokens ----------
INK, SOFT, MIST, MOSS, SKY, LINK, SEP = '#17211B', '#4A5750', '#F2F4EF', '#3B6A4A', '#4A82AB', '#2F6690', '#E7EBE5'
NB = ' '  # non-breaking space between numbers and units

GROUPS = {  # fill, ring (>=3:1 on globe #DCE9F1)
    'veg': ('#4F8A5B', '#2F5A39'), 'grain': ('#E2B54E', '#8A6A1E'), 'protein': ('#7E4127', '#4A2414'),
    'fruit': ('#D07A9A', '#8E4766'), 'legume': ('#8B7AC0', '#5E4F94'),
}

def head(title, extra_css=''):
    return f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700&amp;family=Noto+Sans+KR:wght@400;700&amp;family=Gowun+Dodum&amp;display=swap" rel="stylesheet">
<style>
body{{margin:0}}
a{{color:{LINK}}}a:hover{{color:#24557A}}
::selection{{background:#CFE0EC}}
button:focus-visible,a:focus-visible{{outline:3px solid {SKY};outline-offset:2px}}
input::placeholder{{color:#5C6660}}
{extra_css}
</style>
</helmet>
'''

def tail(props='{"$preview":{"width":390,"height":844}}', script='class Component extends DCLogic {\n  renderVals() { return {}; }\n}'):
    return f'''</x-dc>
<script type="text/x-dc" data-dc-script data-props='{props}'>
{script}
</script>
</body>
</html>
'''

def frame(bg=MIST):
    return f'<div style="width: 390px; height: 844px; box-sizing: border-box; background: {bg}; font-family: Nunito, \'Noto Sans KR\', system-ui, sans-serif; color: {INK}; position: relative; overflow: hidden; font-variant-numeric: tabular-nums">'

# ---------- icons (one outline family, 1.8 stroke; filled variants for selected tabs) ----------
def ic_globe(filled, c):
    if filled:
        return f'<svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" fill="{c}"></circle><path d="M5 9.5c3 1.5 4.5 0 6.5 1.5s1 4 3.5 4.5M14 4.5c-1 2 1 3 3 3.5" stroke="#FFFFFF" stroke-width="1.6" fill="none" stroke-linecap="round"></path></svg>'
    return f'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"></circle><path d="M5 9.5c3 1.5 4.5 0 6.5 1.5s1 4 3.5 4.5M14 4.5c-1 2 1 3 3 3.5"></path></svg>'

def ic_book(c):
    return f'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M6 4h10a2 2 0 0 1 2 2v14H8a2 2 0 0 1-2-2zM6 18a2 2 0 0 1 2-2h10M10 8h5M10 11h3"></path></svg>'

def ic_walk(filled, c, size=24):
    sw = '2.4' if filled else '1.8'
    fill_head = c if filled else 'none'
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="{sw}" stroke-linecap="round" aria-hidden="true"><circle cx="14" cy="4.5" r="1.9" fill="{fill_head}"></circle><path d="M9 21l2.5-5.5 2.5 2V21M7.5 12l3-3.5 3.5 1.5 2.5 3"></path></svg>'

def ic_person(c):
    return f'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="8.5" r="3.5"></circle><path d="M5 20c1-3.8 4-5.5 7-5.5s6 1.7 7 5.5"></path></svg>'

def ic_plus(c, s=20):
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"></path></svg>'

def ic_barcode(c, s=22):
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16M8 9v6M11 9v6M14 9v6M17 9v6"></path></svg>'

def ic_chev(c='#7F8882'):
    return f'<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.6" stroke-linecap="round" aria-hidden="true"><path d="M9 5l7 7-7 7"></path></svg>'

def ic_info(c=SOFT):
    return f'<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"></circle><path d="M12 11v5M12 7.5v.5"></path></svg>'

def ic_ext(c):
    return f'<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"></path></svg>'

def ic_check(c, s=14, sw='3'):
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="{sw}" stroke-linecap="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"></path></svg>'

def ic_shield(c):
    return f'<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.6" stroke-linecap="round" aria-hidden="true"><path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z"></path><path d="M9 12l2 2 4-4"></path></svg>'

def ic_factory(c):
    return f'<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M4 20V9l5-3v4l5-3v4l6-3v12z"></path></svg>'

def ic_people(c):
    return f'<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><circle cx="9" cy="9" r="3"></circle><circle cx="16.5" cy="10" r="2.5"></circle><path d="M3.5 19c.8-3 3-4.5 5.5-4.5s4.7 1.5 5.5 4.5M14 15c2.5-.6 5 .5 6 3.5"></path></svg>'

# ---------- shared components ----------
def tabbar(active):
    tabs = [('My Nuri', 'Main.dc.html', 'today'), ('Diary', '#', 'diary'), ('Plan', 'TodayPlan.dc.html', 'plan'), ('You', '#', 'you')]
    cells = []
    for label, href, key in tabs:
        on = key == active
        c = MOSS if on else '#5C6862'
        icon = {'today': ic_globe(on, c), 'diary': ic_book(c), 'plan': ic_walk(on, c), 'you': ic_person(c)}[key]
        cur = ' aria-current="page"' if on else ''
        bg = 'background: rgba(59,106,74,0.13);' if on else ''
        cells.append(f'<a href="{href}"{cur} style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1px; text-decoration: none; font-size: 11px; font-weight: {700 if on else 600}; color: {c}; min-height: 52px; border-radius: 26px; {bg}">{icon}{label}</a>')
    return ('<nav aria-label="Tabs" style="position: absolute; left: 16px; right: 16px; bottom: 22px; height: 62px; border-radius: 31px; '
            'background: rgba(250,251,248,0.88); box-shadow: 0 8px 24px rgba(23,33,27,0.14), inset 0 0 0 0.5px rgba(23,33,27,0.10); '
            'display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); padding: 5px; box-sizing: border-box">'
            + ''.join(cells) + '</nav>')

def blob(left, top, w, h, radius, group, resting=False):
    fill, ring = GROUPS[group]
    if resting:
        return f'<div style="position: absolute; left: {left}px; top: {top}px; width: {w}px; height: {h}px; border-radius: {radius}; background: rgba(139,122,192,0.18); border: 2px dashed {ring}; box-sizing: border-box"></div>'
    return f'<div style="position: absolute; left: {left}px; top: {top}px; width: {w}px; height: {h}px; border-radius: {radius}; background: {fill}; border: 2px solid {ring}; box-shadow: 0 0 0 1.5px #FFFFFF; box-sizing: border-box"></div>'

def world(size, label):
    k = size / 196
    def s(v): return round(v * k)
    return (f'<div role="img" aria-label="{label}" style="width: {size}px; height: {size}px; border-radius: {size // 2}px; background: #DCE9F1; position: relative; overflow: hidden; '
            f'box-shadow: 0 10px 24px rgba(36,64,52,0.12), inset -16px -12px 0 rgba(23,33,27,0.05)">'
            + blob(s(18), s(44), s(86), s(64), '44% 38% 50% 30% / 50% 44% 56% 40%', 'veg')
            + blob(s(100), s(24), s(70), s(52), '42% 56% 36% 60% / 50% 60% 44% 56%', 'grain')
            + blob(s(66), s(112), s(96), s(58), '42% 52% 36% 48% / 56% 60% 44% 52%', 'protein')
            + blob(s(146), s(86), s(40), s(40), '50%', 'fruit')
            + blob(s(26), s(130), s(34), s(30), '50%', 'legume', resting=True)
            + '</div>')

WORLD_LABEL = 'Your world today: vegetables, grains, protein and fruit. Legumes rest from earlier this week.'

def legend():
    items = [('veg', 'Vegetables'), ('grain', 'Grains'), ('protein', 'Protein'), ('fruit', 'Fruit')]
    li = ''.join(f'<li style="display: flex; align-items: center; gap: 6px"><span style="width: 11px; height: 11px; border-radius: 6px; background: {GROUPS[g][0]}; box-shadow: inset 0 0 0 1.5px {GROUPS[g][1]}"></span>{t}</li>' for g, t in items)
    li += f'<li style="display: flex; align-items: center; gap: 6px"><span style="width: 11px; height: 11px; border-radius: 6px; border: 1.5px dashed {GROUPS["legume"][1]}; box-sizing: border-box"></span>Legumes, earlier this week</li>'
    return f'<ul aria-hidden="true" style="list-style: none; margin: 0; padding: 0 8px; display: flex; gap: 6px 14px; flex-wrap: wrap; justify-content: center; font-size: 13px; color: {SOFT}">{li}</ul>'

def today_header():
    return (f'<header style="display: flex; align-items: flex-end; justify-content: space-between; padding: 6px 4px 10px 4px">'
            f'<div style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 15px; font-weight: 600; color: {SOFT}">Thursday, October 8</span>'
            f'<h1 style="margin: 0; font-size: 34px; line-height: 41px; font-weight: 700; letter-spacing: -0.4px">My Nuri</h1></div>'
            f'<span aria-hidden="true" style="font-family: \'Gowun Dodum\', sans-serif; font-size: 22px; color: {MOSS}; padding-bottom: 6px">누리</span></header>')

def world_block(size=188):
    return (f'<section aria-label="Your world" style="display: flex; flex-direction: column; align-items: center; gap: 12px; padding: 2px 0 16px 0">'
            + world(size, WORLD_LABEL)
            + '<p style="margin: 0; font-size: 17px; line-height: 22px; font-weight: 600; text-align: center; max-width: 300px">Today: vegetables, grains, protein and fruit.</p>'
            + legend() + '</section>')

def add_buttons():
    return (f'<div style="display: flex; gap: 10px; padding-bottom: 16px">'
            f'<a href="FoodSearch.dc.html" style="flex-grow: 1; min-height: 52px; border-radius: 14px; background: {MOSS}; color: #FFFFFF; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 17px; font-weight: 700">{ic_plus("currentColor")}Add food</a>'
            f'<a href="FoodSearch.dc.html" aria-label="Scan a barcode" style="width: 52px; min-height: 52px; border-radius: 14px; background: #FFFFFF; color: {MOSS}; display: flex; align-items: center; justify-content: center; box-shadow: inset 0 0 0 1px #C9D0C8">{ic_barcode("currentColor")}</a></div>')

def row_sep(inset=16):
    return f'<div style="height: 1px; background: {SEP}; margin-left: {inset}px"></div>'

# ---------- boards ----------
def board_today():
    script = '''class Component extends DCLogic {
  renderVals() {
    const over = this.props.overTarget ?? false;
    return {
      soFar: over ? '2,120\\u00a0kcal so far' : '1,240\\u00a0kcal so far',
      guide: over ? 'Daily guide about 2,000\\u00a0kcal. A guide, not a limit.' : 'Daily guide about 2,000\\u00a0kcal',
      now: over ? 2000 : 1240,
      valueText: over ? '2,120 of about 2,000 kilocalories, estimate' : '1,240 of about 2,000 kilocalories, estimate',
      fill: over ? '100%' : '62%'
    };
  }
}'''
    energy = (f'<section aria-label="Today\'s energy" style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">'
              f'<div style="padding: 14px 16px; display: flex; flex-direction: column; gap: 6px">'
              f'<div style="display: flex; justify-content: space-between; align-items: baseline; gap: 12px"><span style="font-size: 17px; font-weight: 700">{{{{soFar}}}}</span><span style="font-size: 13px; color: {SOFT}">Estimates</span></div>'
              f'<div role="progressbar" aria-label="Energy eaten today" aria-valuemin="0" aria-valuemax="2000" aria-valuenow="{{{{now}}}}" aria-valuetext="{{{{valueText}}}}" style="height: 8px; border-radius: 4px; background: #E1E6E0; overflow: hidden; margin-top: 2px"><div style="width: {{{{fill}}}}; height: 8px; border-radius: 4px; background: {SKY}"></div></div>'
              f'<span style="font-size: 15px; color: {SOFT}">{{{{guide}}}}</span></div>'
              + row_sep(50) +
              f'<div style="padding: 12px 16px; display: flex; align-items: center; gap: 12px">{ic_walk(False, LINK, 22)}'
              f'<div style="display: flex; flex-direction: column"><span style="font-size: 15px; font-weight: 600">32{NB}min walk</span><span style="font-size: 13px; color: {SOFT}">From Apple Health, not added to your guide</span></div></div></section>')
    body = (head('My Nuri — today') + frame()
            + '<main style="display: flex; flex-direction: column; padding: 59px 16px 0 16px">'
            + today_header() + world_block() + add_buttons() + energy + '</main>' + tabbar('today') + '</div>\n')
    return body + tail('{"overTarget":{"editor":"boolean","default":false},"$preview":{"width":390,"height":844}}', script)

def board_today_sensitive():
    rows = (f'<section aria-label="Today" style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">'
            f'<a href="#" style="min-height: 60px; padding: 8px 16px; display: flex; align-items: center; gap: 12px; text-decoration: none; color: {INK}">'
            f'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="{MOSS}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M7 3v8M5 3v4a2 2 0 0 0 4 0V3M7 11v10M16 3c-2 1.5-3 4-3 7h3v11"></path></svg>'
            f'<div style="flex-grow: 1; display: flex; flex-direction: column"><span style="font-size: 15px; font-weight: 600">Breakfast and lunch added</span><span style="font-size: 13px; color: {SOFT}">Dinner and snacks whenever you are ready</span></div>{ic_chev()}</a>'
            + row_sep(50) +
            f'<a href="TodayPlan.dc.html" style="min-height: 60px; padding: 8px 16px; display: flex; align-items: center; gap: 12px; text-decoration: none; color: {INK}">{ic_walk(False, LINK, 22)}'
            f'<div style="flex-grow: 1; display: flex; flex-direction: column"><span style="font-size: 15px; font-weight: 600">A short walk</span><span style="font-size: 13px; color: {SOFT}">Suggested for today, if it suits you</span></div>{ic_chev()}</a></section>'
            f'<p style="margin: 10px 4px 0 4px; font-size: 13px; color: {SOFT}">Numbers are hidden. Change this in You, Display.</p>')
    body = (head('My Nuri — today, numbers hidden') + frame()
            + '<main style="display: flex; flex-direction: column; padding: 59px 16px 0 16px">'
            + today_header() + world_block() + add_buttons() + rows + '</main>' + tabbar('today') + '</div>\n')
    return body + tail()

def nutrient_row(name, val, now, mx, pct):
    return (f'<div style="padding: 12px 16px; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 6px 12px; align-items: center">'
            f'<span style="font-size: 15px; font-weight: 600">{name}</span><span style="font-size: 15px; color: {SOFT}">{val}</span>'
            f'<div role="progressbar" aria-label="{name}" aria-valuemin="0" aria-valuemax="{mx}" aria-valuenow="{now}" aria-valuetext="{now} of {mx} grams" style="grid-column: 1 / span 2; height: 6px; border-radius: 3px; background: #E1E6E0"><div style="width: {pct}; height: 6px; border-radius: 3px; background: {SKY}"></div></div></div>')

def board_today_scrolled():
    nav = (f'<header style="position: absolute; left: 0; right: 0; top: 0; height: 103px; background: rgba(242,244,239,0.92); border-bottom: 1px solid #DDE2DA; display: flex; align-items: flex-end; justify-content: center; padding-bottom: 11px; box-sizing: border-box; z-index: 1">'
           f'<h1 style="margin: 0; font-size: 17px; font-weight: 700">My Nuri</h1></header>')
    nutrients = (f'<section aria-labelledby="nutrients-h" style="display: flex; flex-direction: column; gap: 8px">'
                 f'<h2 id="nutrients-h" style="margin: 0 4px; font-size: 22px; line-height: 28px; font-weight: 700">Nutrients</h2>'
                 f'<div style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">'
                 + nutrient_row('Protein', f'62 of 90{NB}g', 62, 90, '69%') + row_sep()
                 + nutrient_row('Fiber', f'14 of 25{NB}g', 14, 25, '56%') + row_sep()
                 + f'<a href="#" style="min-height: 48px; padding: 0 16px; display: flex; align-items: center; justify-content: space-between; text-decoration: none; color: {INK}; font-size: 15px">Carbs, fat and more{ic_chev()}</a></div></section>')
    meals = (f'<section aria-labelledby="meals-h" style="display: flex; flex-direction: column; gap: 8px">'
             f'<h2 id="meals-h" style="margin: 0 4px; font-size: 22px; line-height: 28px; font-weight: 700">Meals</h2>'
             f'<div style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">'
             f'<a href="#" style="min-height: 60px; padding: 8px 16px; display: flex; align-items: center; gap: 12px; text-decoration: none; color: {INK}"><div style="flex-grow: 1; display: flex; flex-direction: column"><span style="font-size: 15px; font-weight: 600">Breakfast</span><span style="font-size: 13px; color: {SOFT}">Eggs, toast, coffee with milk</span></div>{ic_chev()}</a>'
             + row_sep() +
             f'<a href="#" style="min-height: 60px; padding: 8px 16px; display: flex; align-items: center; gap: 12px; text-decoration: none; color: {INK}"><div style="flex-grow: 1; display: flex; flex-direction: column"><span style="font-size: 15px; font-weight: 600">Lunch</span><span style="font-size: 13px; color: {SOFT}">Bibimbap, kimchi</span></div>{ic_chev()}</a>'
             + row_sep() +
             f'<a href="FoodSearch.dc.html" style="min-height: 52px; padding: 0 16px; display: flex; align-items: center; gap: 10px; text-decoration: none; color: {MOSS}; font-size: 15px; font-weight: 700">{ic_plus("currentColor", 18)}Add dinner</a></div></section>')
    ad = (f'<section aria-label="Advertisement" style="background: #FFFFFF; border-radius: 16px; box-shadow: inset 0 0 0 1.5px #858B83; padding: 12px 16px 14px 16px; display: flex; flex-direction: column; gap: 8px">'
          f'<div style="display: flex; align-items: center; justify-content: space-between"><span style="font-size: 13px; font-weight: 700; color: #3A403C">Ad · [Partner]</span>'
          f'<button aria-label="Why this ad, and hide options" style="min-width: 44px; min-height: 44px; margin: -12px -12px -12px 0; border: none; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">{ic_info()}</button></div>'
          f'<div style="display: flex; gap: 12px; align-items: center"><div aria-hidden="true" style="width: 56px; height: 56px; border-radius: 12px; background: #EADFC8; flex-shrink: 0"></div>'
          f'<div style="display: flex; flex-direction: column; gap: 2px; min-width: 0"><span style="font-size: 17px; font-weight: 700">[Partner] seasonal vegetable box</span><span style="font-size: 13px; color: {SOFT}">Delivered weekly, nutrition on each label</span></div></div>'
          f'<a href="#" style="min-height: 44px; border-radius: 12px; background: {MIST}; display: flex; align-items: center; justify-content: center; gap: 6px; text-decoration: none; color: {INK}; font-size: 15px; font-weight: 700">View on [Partner]{ic_ext(INK)}</a></section>')
    body = (head('My Nuri — today, scrolled') + frame() + nav
            + '<main style="display: flex; flex-direction: column; gap: 24px; padding: 119px 16px 0 16px">' + nutrients + meals + ad + '</main>'
            + tabbar('today') + '</div>\n')
    return body + tail()

def result_row(name, sub, label_html, kcal, korean=False):
    name_style = "font-family: 'Noto Sans KR', Nunito, sans-serif; font-weight: 700;" if korean else 'font-weight: 600;'
    return (f'<a href="FoodDetail.dc.html" style="min-height: 64px; padding: 10px 16px; display: flex; align-items: center; gap: 12px; text-decoration: none; color: {INK}">'
            f'<div style="flex-grow: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px"><span style="font-size: 17px; {name_style} line-height: 22px">{name}</span>'
            f'<span style="font-size: 13px; color: {SOFT}; display: flex; align-items: center; gap: 8px; flex-wrap: wrap">{sub}{label_html}</span></div>'
            f'<sc-if value="{{{{ showKcal }}}}" hint-placeholder-val="{{{{ true }}}}"><span style="font-size: 15px; color: {SOFT}; white-space: nowrap">{kcal}</span></sc-if></a>')

def src(kind, text, spoken):
    color, icon = {'verified': ('#2D5E3D', ic_shield), 'maker': (LINK, ic_factory), 'community': ('#7A4E0C', ic_people)}[kind]
    return f'<span aria-label="{spoken}" style="display: inline-flex; align-items: center; gap: 3px; color: {color}; font-weight: 600">{icon(color)}<span aria-hidden="true">{text}</span></span>'

def sheet_bg():
    return ('<div aria-hidden="true" style="position: absolute; left: 10px; right: 10px; top: 50px; height: 40px; border-radius: 14px 14px 0 0; background: #8E9791"></div>')

def board_search():
    script = 'class Component extends DCLogic {\n  renderVals() { return { showKcal: !(this.props.numbersHidden ?? false) }; }\n}'
    rows = (result_row('Rice, white, cooked', f'1 bowl, 210{NB}g', src('verified', 'USDA', 'Verified by USDA'), f'273{NB}kcal')
            + row_sep()
            + result_row('[브랜드] 김치볶음밥', 'Kimchi fried rice, 1 pack', src('verified', 'MFDS 식약처', 'Verified by the Korean Ministry of Food and Drug Safety'), '[kcal]', korean=True)
            + row_sep()
            + result_row('[Brand] brown rice bowl', '1 container', src('community', 'Community, check values', 'Community entry, check values'), '[kcal]'))
    ad = (f'<div style="margin-top: 4px; background: #FFFFFF; border-radius: 16px; box-shadow: inset 0 0 0 1.5px #858B83; display: flex; align-items: flex-start">'
          f'<a href="FoodDetail.dc.html" style="flex-grow: 1; min-width: 0; min-height: 72px; padding: 10px 0 10px 16px; display: flex; flex-direction: column; gap: 3px; text-decoration: none; color: {INK}">'
          f'<span style="font-size: 13px; font-weight: 700; color: #3A403C">Ad · [Partner]</span>'
          f'<span style="font-size: 17px; font-weight: 600; line-height: 22px">[Partner] multigrain rice pouch</span>'
          f'<span style="font-size: 13px; color: {SOFT}; display: flex; align-items: center; gap: 8px; flex-wrap: wrap">1 pouch{src("maker", "Manufacturer data", "Manufacturer data")}<sc-if value="{{{{ showKcal }}}}" hint-placeholder-val="{{{{ true }}}}"><span>[kcal]</span></sc-if></span></a>'
          f'<button aria-label="Why this ad, and hide options" style="min-width: 44px; min-height: 44px; margin: 4px 4px 0 0; border: none; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer">{ic_info()}</button></div>')
    quick = ''.join(
        f'<button style="min-height: 64px; border: none; border-radius: 12px; background: #FFFFFF; font-family: inherit; font-size: 13px; font-weight: 600; color: {INK}; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; cursor: pointer">{icon}{label}</button>'
        for icon, label in [(ic_barcode(MOSS), 'Scan barcode'),
                            (f'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="{MOSS}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><rect x="5" y="3.5" width="14" height="17" rx="2"></rect><path d="M8.5 8h7M8.5 11.5h7M8.5 15h4"></path></svg>', 'Scan label'),
                            (f'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="{MOSS}" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M14.5 4.5l5 5L9 20H4v-5z"></path></svg>', 'Create food')])
    body = (head('Add food to lunch') + frame('#3A4540') + sheet_bg()
            + f'<section role="dialog" aria-modal="true" aria-label="Add food to lunch" style="position: absolute; left: 0; right: 0; top: 62px; bottom: 0; background: {MIST}; border-radius: 14px 14px 0 0; display: flex; flex-direction: column">'
            + '<div aria-hidden="true" style="width: 36px; height: 5px; border-radius: 3px; background: #B9C1BB; margin: 6px auto 0 auto"></div>'
            + f'<div style="display: grid; grid-template-columns: minmax(80px, auto) minmax(0, 1fr) minmax(80px, auto); align-items: center; padding: 4px 8px 0 8px">'
            + f'<a href="Main.dc.html" style="min-height: 44px; display: flex; align-items: center; padding: 0 8px; text-decoration: none; font-size: 17px; color: {MOSS}">Cancel</a>'
            + f'<button aria-label="Adding to lunch. Change meal" style="min-height: 44px; border: none; background: transparent; font-family: inherit; color: {INK}; display: flex; flex-direction: column; align-items: center; justify-content: center; cursor: pointer"><span style="font-size: 17px; font-weight: 700">Add food</span><span style="font-size: 13px; color: {SOFT}; display: flex; align-items: center; gap: 3px">to lunch<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" aria-hidden="true"><path d="M6 9l6 6 6-6"></path></svg></span></button><span></span></div>'
            + '<div style="padding: 8px 16px 12px 16px; display: flex; flex-direction: column; gap: 12px">'
            + '<label style="position: relative; display: block"><span style="position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0)">Search foods</span>'
            + f'<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#5C6862" stroke-width="2.2" stroke-linecap="round" aria-hidden="true" style="position: absolute; left: 12px; top: 13px"><circle cx="11" cy="11" r="6.5"></circle><path d="M20 20l-4-4"></path></svg>'
            + f'<input type="search" value="rice" placeholder="Search foods or brands" style="width: 100%; height: 44px; box-sizing: border-box; border: none; border-radius: 12px; background: #E3E8E2; padding: 0 44px 0 38px; font-family: inherit; font-size: 17px; color: {INK}"></label>'
            + f'<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px">{quick}</div></div>'
            + f'<section aria-labelledby="results-h" style="padding: 0 16px; display: flex; flex-direction: column; gap: 8px">'
            + f'<h2 id="results-h" style="margin: 0 4px; font-size: 13px; font-weight: 600; color: {SOFT}">Results for “rice”</h2>'
            + f'<div style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">{rows}</div>{ad}</section></section></div>\n')
    return body + tail('{"numbersHidden":{"editor":"boolean","default":false},"$preview":{"width":390,"height":844}}', script)

def board_detail():
    script = r'''class Component extends DCLogic {
  constructor(props) { super(props); this.state = { unit: 'bowl', bowls: 1, grams: 210, added: false }; }
  renderVals() {
    const s = this.state;
    const hidden = this.props.numbersHidden ?? false;
    const g = s.unit === 'bowl' ? Math.round(210 * s.bowls) : s.grams;
    const per = g / 100;
    const bowlText = (s.bowls % 1 === 0 ? String(s.bowls) : s.bowls.toFixed(1)) + (s.bowls === 1 ? ' bowl' : ' bowls');
    const title = s.unit === 'bowl' ? bowlText : g + ' g';
    const atMin = s.unit === 'bowl' ? s.bowls <= 0.5 : s.grams <= 10;
    const on = { bg: '#FFFFFF', shadow: '0 1px 3px rgba(23,33,27,0.18), inset 0 0 0 1px #B9C1BB' };
    const off = { bg: 'transparent', shadow: 'none' };
    const b = s.unit === 'bowl' ? on : off, gr = s.unit === 'gram' ? on : off;
    return {
      showNumbers: !hidden,
      hideNumbers: hidden,
      portionTitle: title,
      portionSub: hidden ? 'Adjust to what you had' : (s.unit === 'bowl' ? g + ' g' : 'about ' + (g / 210).toFixed(1) + ' bowl'),
      portionSpoken: 'Portion, ' + title + (hidden ? '' : ', ' + g + ' grams'),
      kcal: Math.round(130 * per), carbs: (28.2 * per).toFixed(1), protein: (2.7 * per).toFixed(1), fat: (0.3 * per).toFixed(1),
      bowlChecked: s.unit === 'bowl' ? 'true' : 'false', gramChecked: s.unit === 'gram' ? 'true' : 'false',
      bowlBg: b.bg, bowlShadow: b.shadow, gramBg: gr.bg, gramShadow: gr.shadow,
      atMin: atMin, lessOpacity: atMin ? '0.4' : '1',
      useBowl: () => this.setState({ unit: 'bowl' }),
      useGram: () => this.setState({ unit: 'gram', grams: g }),
      less: () => atMin ? null : (s.unit === 'bowl' ? this.setState({ bowls: s.bowls - 0.5 }) : this.setState({ grams: s.grams - 10 })),
      more: () => s.unit === 'bowl' ? this.setState({ bowls: Math.min(5, s.bowls + 0.5) }) : this.setState({ grams: Math.min(1000, s.grams + 10) }),
      added: s.added, notAdded: !s.added,
      add: () => this.setState({ added: true }),
      undo: () => this.setState({ added: false })
    };
  }
}'''
    seg_btn = lambda label, chk, click, bg, sh: (f'<button role="radio" aria-checked="{{{{{chk}}}}}" onClick="{{{{ {click} }}}}" style="min-height: 40px; border: none; border-radius: 9px; font-family: inherit; font-size: 15px; font-weight: 600; cursor: pointer; color: {INK}; background: {{{{{bg}}}}}; box-shadow: {{{{{sh}}}}}">{label}</button>')
    grid_cell = lambda t, v: f'<div style="padding: 10px 0; display: flex; flex-direction: column"><dt style="font-size: 13px; color: {SOFT}">{t}</dt><dd style="margin: 0; font-size: 17px; font-weight: 700">{v}</dd></div>'
    nutrition = (f'<sc-if value="{{{{ showNumbers }}}}" hint-placeholder-val="{{{{ true }}}}"><dl style="margin: 0; background: #FFFFFF; border-radius: 16px; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); padding: 4px 16px">'
                 + grid_cell('Energy', '{{kcal}} kcal') + grid_cell('Carbs', '{{carbs}} g') + grid_cell('Protein', '{{protein}} g') + grid_cell('Fat', '{{fat}} g') + '</dl></sc-if>'
                 + f'<sc-if value="{{{{ hideNumbers }}}}" hint-placeholder-val="{{{{ false }}}}"><div style="background: #FFFFFF; border-radius: 16px; padding: 14px 16px; display: flex; align-items: center; gap: 10px; font-size: 15px"><span style="width: 12px; height: 12px; border-radius: 6px; background: {GROUPS["grain"][0]}; box-shadow: inset 0 0 0 1.5px {GROUPS["grain"][1]}"></span>Grains, adds to your world</div></sc-if>')
    pick_row = lambda label, val: f'<button style="min-height: 48px; padding: 0 16px; border: none; background: transparent; font-family: inherit; font-size: 15px; color: {INK}; display: flex; align-items: center; justify-content: space-between; cursor: pointer">{label}<span style="color: {SOFT}; display: flex; align-items: center; gap: 6px">{val}{ic_chev()}</span></button>'
    actions = (f'<div style="position: absolute; left: 16px; right: 16px; bottom: 34px; display: flex; flex-direction: column; gap: 10px">'
               f'<sc-if value="{{{{ notAdded }}}}" hint-placeholder-val="{{{{ true }}}}"><button onClick="{{{{ add }}}}" style="width: 100%; min-height: 52px; border: none; border-radius: 14px; background: {MOSS}; color: #FFFFFF; font-family: inherit; font-size: 17px; font-weight: 700; cursor: pointer">Add to lunch</button></sc-if>'
               f'<sc-if value="{{{{ added }}}}" hint-placeholder-val="{{{{ false }}}}"><div style="display: flex; flex-direction: column; gap: 10px">'
               f'<div role="status" style="background: {INK}; color: #FFFFFF; border-radius: 14px; padding: 4px 6px 4px 14px; display: flex; align-items: center; gap: 10px">'
               f'<span aria-hidden="true" style="width: 22px; height: 22px; border-radius: 11px; background: #2E5539; display: flex; align-items: center; justify-content: center">{ic_check("#FFFFFF", 13)}</span>'
               f'<span style="flex-grow: 1; font-size: 15px; font-weight: 600">Added to lunch</span>'
               f'<button onClick="{{{{ undo }}}}" style="min-height: 44px; padding: 0 12px; border: none; background: transparent; color: #A9D3B4; font-family: inherit; font-size: 15px; font-weight: 700; cursor: pointer">Undo</button></div>'
               f'<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px">'
               f'<a href="FoodSearch.dc.html" style="min-height: 52px; border-radius: 14px; background: #FFFFFF; box-shadow: inset 0 0 0 1px #C9D0C8; display: flex; align-items: center; justify-content: center; text-decoration: none; color: {INK}; font-size: 17px; font-weight: 700">Add another food</a>'
               f'<a href="Main.dc.html" style="min-height: 52px; border-radius: 14px; background: {MOSS}; display: flex; align-items: center; justify-content: center; text-decoration: none; color: #FFFFFF; font-size: 17px; font-weight: 700">Done</a></div></div></sc-if></div>')
    body = (head('Rice, white, cooked — add to lunch') + frame('#3A4540') + sheet_bg()
            + f'<section role="dialog" aria-modal="true" aria-label="Rice, white, cooked" style="position: absolute; left: 0; right: 0; top: 62px; bottom: 0; background: {MIST}; border-radius: 14px 14px 0 0; display: flex; flex-direction: column">'
            + '<div aria-hidden="true" style="width: 36px; height: 5px; border-radius: 3px; background: #B9C1BB; margin: 6px auto 0 auto"></div>'
            + f'<div style="display: flex; justify-content: space-between; align-items: center; padding: 4px 8px 0 8px">'
            + f'<a href="FoodSearch.dc.html" style="min-height: 44px; display: flex; align-items: center; gap: 2px; padding-right: 8px; text-decoration: none; font-size: 17px; color: {MOSS}"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" aria-hidden="true"><path d="M15 5l-7 7 7 7"></path></svg>Search</a>'
            + f'<a href="Main.dc.html" style="min-height: 44px; display: flex; align-items: center; padding: 0 8px; text-decoration: none; font-size: 17px; color: {MOSS}">Cancel</a></div>'
            + f'<div style="padding: 2px 20px 0 20px; display: flex; flex-direction: column; gap: 4px"><h2 style="margin: 0; font-size: 28px; line-height: 34px; font-weight: 700">Rice, white, cooked</h2>'
            + f'<span style="font-size: 15px; color: #2D5E3D; font-weight: 600; display: flex; align-items: center; gap: 6px">{ic_shield("#2D5E3D")}Verified, USDA FoodData Central</span></div>'
            + '<div style="padding: 18px 16px 0 16px; display: flex; flex-direction: column; gap: 14px">'
            + '<div role="radiogroup" aria-label="Portion unit" style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); background: #E3E8E2; border-radius: 11px; padding: 2px">'
            + seg_btn('Bowl', 'bowlChecked', 'useBowl', 'bowlBg', 'bowlShadow') + seg_btn('Grams', 'gramChecked', 'useGram', 'gramBg', 'gramShadow') + '</div>'
            + f'<div role="group" aria-label="{{{{portionSpoken}}}}" style="background: #FFFFFF; border-radius: 16px; padding: 12px; display: flex; align-items: center; gap: 12px">'
            + f'<button aria-label="Decrease portion" aria-disabled="{{{{ atMin }}}}" onClick="{{{{ less }}}}" style="width: 48px; height: 48px; border-radius: 24px; border: none; background: #E3E8E2; color: {INK}; display: flex; align-items: center; justify-content: center; cursor: pointer; opacity: {{{{lessOpacity}}}}"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14"></path></svg></button>'
            + f'<div aria-live="polite" style="flex-grow: 1; display: flex; flex-direction: column; align-items: center"><span style="font-size: 22px; line-height: 28px; font-weight: 700">{{{{portionTitle}}}}</span><span style="font-size: 13px; color: {SOFT}">{{{{portionSub}}}}</span></div>'
            + f'<button aria-label="Increase portion" onClick="{{{{ more }}}}" style="width: 48px; height: 48px; border-radius: 24px; border: none; background: #E3E8E2; color: {INK}; display: flex; align-items: center; justify-content: center; cursor: pointer">{ic_plus("currentColor")}</button></div>'
            + nutrition
            + f'<div style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">{pick_row("Meal", "Lunch")}{row_sep()}{pick_row("Time", "Today, 12:30")}</div>'
            + '</div>' + actions + '</section></div>\n')
    return body + tail('{"numbersHidden":{"editor":"boolean","default":false},"$preview":{"width":390,"height":844}}', script)

def day(label_vis, spoken, kind, bold=False):
    if kind == 'done':
        dot = f'<span style="width: 28px; height: 28px; border-radius: 14px; background: {SKY}; display: flex; align-items: center; justify-content: center">{ic_check("#FFFFFF", 14)}</span>'
    elif kind == 'rest':
        dot = '<span style="width: 28px; height: 28px; border-radius: 14px; box-shadow: inset 0 0 0 2px #7F8882"></span>'
    elif kind == 'today':
        dot = (f'<span style="width: 28px; height: 28px; border-radius: 14px; box-shadow: inset 0 0 0 2.5px {LINK}; background: {{{{todayBg}}}}; display: flex; align-items: center; justify-content: center">'
               f'<sc-if value="{{{{ walkDone }}}}" hint-placeholder-val="{{{{ false }}}}">{ic_check("#FFFFFF", 14)}</sc-if></span>')
    else:
        dot = '<span style="width: 28px; height: 28px; border-radius: 14px; border: 2px dotted #7F8882; box-sizing: border-box"></span>'
    cur = ' aria-current="date"' if kind == 'today' else ''
    weight = f'color: {INK}; font-weight: 700;' if bold else ''
    return f'<li aria-label="{spoken}"{cur} style="display: flex; flex-direction: column; align-items: center; gap: 4px; {weight}">{dot}{label_vis}</li>'

def board_plan():
    script = r'''class Component extends DCLogic {
  constructor(props) { super(props); this.state = { walkDone: false, whyOpen: false }; }
  renderVals() {
    const show = this.props.showCalories ?? false;
    const hidden = this.props.numbersHidden ?? false;
    const done = this.state.walkDone;
    const mins = done ? 93 : 65;
    return {
      walkKcal: show && !hidden ? ', about 95–175 kcal' : '',
      strengthKcal: show && !hidden ? ', about 60–160 kcal' : '',
      walkMeta: hidden ? 'An easy, steady walk' : '25–30 min, moderate',
      strengthMeta: hidden ? 'First of two this week' : '15–25 min, first of 2 this week',
      showWeekNumbers: !hidden,
      walkDone: done, walkOpen: !done,
      toggleWalk: () => this.setState({ walkDone: !done }),
      weekMinutes: mins, weekLabel: mins + ' of 150 min',
      weekValueText: mins + ' of 150 active minutes this week',
      weekFill: Math.round(mins / 150 * 100) + '%',
      todaySpoken: done ? 'Thursday, today, walk logged' : 'Thursday, today',
      todayBg: done ? '#4A82AB' : 'transparent',
      whyOpen: this.state.whyOpen,
      chevronTurn: this.state.whyOpen ? 'rotate(180deg)' : 'none',
      toggleWhy: () => this.setState({ whyOpen: !this.state.whyOpen })
    };
  }
}'''
    days = (day('Mon', 'Monday, active', 'done') + day('Tue', 'Tuesday, rest day', 'rest') + day('Wed', 'Wednesday, active', 'done')
            + day('Today', '{{todaySpoken}}', 'today', bold=True)
            + day('Fri', 'Friday, planned', 'future') + day('Sat', 'Saturday, planned', 'future') + day('Sun', 'Sunday, planned', 'future'))
    week = (f'<section aria-labelledby="week-h" style="background: #FFFFFF; border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 12px">'
            f'<div style="display: flex; justify-content: space-between; align-items: baseline"><h2 id="week-h" style="margin: 0; font-size: 17px; font-weight: 700">This week</h2>'
            f'<sc-if value="{{{{ showWeekNumbers }}}}" hint-placeholder-val="{{{{ true }}}}"><span style="font-size: 15px; color: {SOFT}">{{{{weekLabel}}}}</span></sc-if></div>'
            f'<sc-if value="{{{{ showWeekNumbers }}}}" hint-placeholder-val="{{{{ true }}}}"><div role="progressbar" aria-label="Active minutes this week" aria-valuemin="0" aria-valuemax="150" aria-valuenow="{{{{weekMinutes}}}}" aria-valuetext="{{{{weekValueText}}}}" style="height: 8px; border-radius: 4px; background: #E1E6E0; overflow: hidden"><div style="width: {{{{weekFill}}}}; height: 8px; border-radius: 4px; background: {SKY}"></div></div></sc-if>'
            f'<ol aria-label="Days this week" style="list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); text-align: center; font-size: 12px; color: {SOFT}">{days}</ol>'
            f'<span style="font-size: 13px; color: {SOFT}">Rest days are part of the plan.</span></section>')
    walk_actions = (f'<div style="display: flex; gap: 8px; padding-top: 8px; align-items: center">'
                    f'<sc-if value="{{{{ walkOpen }}}}" hint-placeholder-val="{{{{ true }}}}"><button onClick="{{{{ toggleWalk }}}}" aria-label="Log brisk walk" style="min-height: 44px; padding: 0 16px; border-radius: 12px; border: none; background: #E3E8E2; font-family: inherit; font-size: 15px; font-weight: 700; color: {INK}; cursor: pointer">Log it</button></sc-if>'
                    f'<sc-if value="{{{{ walkDone }}}}" hint-placeholder-val="{{{{ false }}}}"><span role="status" style="min-height: 44px; padding: 0 14px; border-radius: 12px; background: {MOSS}; color: #FFFFFF; font-size: 15px; font-weight: 700; display: inline-flex; align-items: center; gap: 6px">{ic_check("#FFFFFF", 14)}Logged</span>'
                    f'<button onClick="{{{{ toggleWalk }}}}" aria-label="Undo brisk walk" style="min-height: 44px; padding: 0 12px; border: none; background: transparent; font-family: inherit; font-size: 15px; font-weight: 600; color: {MOSS}; cursor: pointer">Undo</button></sc-if>'
                    f'<button aria-label="Swap brisk walk for another activity" style="min-height: 44px; padding: 0 12px; border: none; background: transparent; font-family: inherit; font-size: 15px; font-weight: 600; color: {MOSS}; cursor: pointer">Swap</button></div>')
    walk = (f'<div style="padding: 14px 16px; display: flex; gap: 12px; align-items: flex-start">'
            f'<span aria-hidden="true" style="width: 40px; height: 40px; border-radius: 12px; background: #E1ECF4; display: flex; align-items: center; justify-content: center; flex-shrink: 0">{ic_walk(False, LINK, 22)}</span>'
            f'<div style="flex-grow: 1; display: flex; flex-direction: column; gap: 2px"><h3 style="margin: 0; font-size: 17px; font-weight: 700">Brisk walk</h3>'
            f'<span style="font-size: 15px; color: {SOFT}">{{{{walkMeta}}}}{{{{walkKcal}}}}</span><span style="font-size: 13px; color: {SOFT}">A pace where you can talk but not sing.</span>{walk_actions}</div></div>')
    strength = (f'<div style="padding: 14px 16px; display: flex; gap: 12px; align-items: flex-start">'
                f'<span aria-hidden="true" style="width: 40px; height: 40px; border-radius: 12px; background: #E3EEE5; display: flex; align-items: center; justify-content: center; flex-shrink: 0"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="{MOSS}" stroke-width="1.8" stroke-linecap="round"><path d="M3 10v4M6 8v8M18 8v8M21 10v4M6 12h12"></path></svg></span>'
                f'<div style="flex-grow: 1; display: flex; flex-direction: column; gap: 2px"><h3 style="margin: 0; font-size: 17px; font-weight: 700">Bodyweight strength</h3>'
                f'<span style="font-size: 15px; color: {SOFT}">{{{{strengthMeta}}}}{{{{strengthKcal}}}}</span>'
                f'<a href="#" style="min-height: 44px; display: flex; align-items: center; justify-content: space-between; text-decoration: none; color: {INK}; font-size: 15px">How to do these{ic_chev()}</a>'
                f'<div style="display: flex; gap: 8px"><button aria-label="Log bodyweight strength" style="min-height: 44px; padding: 0 16px; border-radius: 12px; border: none; background: #E3E8E2; font-family: inherit; font-size: 15px; font-weight: 700; color: {INK}; cursor: pointer">Log it</button>'
                f'<button aria-label="Swap bodyweight strength for another activity" style="min-height: 44px; padding: 0 12px; border: none; background: transparent; font-family: inherit; font-size: 15px; font-weight: 600; color: {MOSS}; cursor: pointer">Swap</button></div></div></div>')
    why = (f'<section aria-label="Why this plan" style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">'
           f'<button onClick="{{{{ toggleWhy }}}}" aria-expanded="{{{{ whyOpen }}}}" style="min-height: 48px; padding: 0 16px; border: none; background: transparent; font-family: inherit; font-size: 15px; font-weight: 700; color: {INK}; display: flex; justify-content: space-between; align-items: center; cursor: pointer">Why this plan'
           f'<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#5C6862" stroke-width="2.6" stroke-linecap="round" aria-hidden="true" style="transform: {{{{chevronTurn}}}}"><path d="M6 9l6 6 6-6"></path></svg></button>'
           f'<sc-if value="{{{{ whyOpen }}}}" hint-placeholder-val="{{{{ false }}}}"><div style="padding: 0 16px 14px 16px; display: flex; flex-direction: column; gap: 8px; font-size: 15px; line-height: 21px">'
           f'<p style="margin: 0">The WHO suggests 150–300 minutes of moderate activity a week, with strength work on two days.</p>'
           f'<p style="margin: 0">Your weekly minutes grow by at most 10%, so each week stays comfortable.</p>'
           f'<p style="margin: 0; color: {SOFT}">Energy estimates use the Compendium of Physical Activities and vary with pace, terrain and body size.</p></div></sc-if></section>')
    body = (head('Plan — suggestions for your week') + frame()
            + '<main style="display: flex; flex-direction: column; gap: 20px; padding: 59px 16px 0 16px">'
            + f'<header style="display: flex; flex-direction: column; gap: 2px; padding: 6px 4px 0 4px"><h1 style="margin: 0; font-size: 34px; line-height: 41px; font-weight: 700; letter-spacing: -0.4px">Plan</h1><span style="font-size: 15px; color: {SOFT}">Suggestions for your week, never required.</span></header>'
            + week
            + f'<section aria-labelledby="today-h" style="display: flex; flex-direction: column; gap: 8px"><h2 id="today-h" style="margin: 0 4px; font-size: 22px; line-height: 28px; font-weight: 700">Today\'s suggestions</h2>'
            + f'<div style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">{walk}{row_sep(68)}{strength}</div></section>'
            + why + '</main>' + tabbar('plan') + '</div>\n')
    return body + tail('{"showCalories":{"editor":"boolean","default":false},"numbersHidden":{"editor":"boolean","default":false},"$preview":{"width":390,"height":844}}', script)

def big30(svg):
    return svg.replace('width="24" height="24"', 'width="30" height="30"')

def board_today_large():
    big = (f'<main style="display: flex; flex-direction: column; gap: 18px; padding: 59px 16px 0 16px">'
           f'<header style="display: flex; flex-direction: column; gap: 4px; padding: 6px 4px 0 4px"><span style="font-size: 22px; font-weight: 600; color: {SOFT}">Thursday, October 8</span>'
           f'<h1 style="margin: 0; font-size: 44px; line-height: 52px; font-weight: 700; letter-spacing: -0.4px">My Nuri</h1></header>'
           f'<div style="display: flex; gap: 16px; align-items: center">' + world(112, WORLD_LABEL)
           + f'<p style="margin: 0; font-size: 24px; line-height: 30px; font-weight: 600">Today: vegetables, grains, protein and fruit.</p></div>'
           f'<a href="FoodSearch.dc.html" style="min-height: 64px; border-radius: 16px; background: {MOSS}; color: #FFFFFF; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 10px; font-size: 24px; font-weight: 700">{ic_plus("currentColor", 26)}Add food</a>'
           f'<a href="FoodSearch.dc.html" style="min-height: 64px; border-radius: 16px; background: #FFFFFF; box-shadow: inset 0 0 0 1px #C9D0C8; color: {MOSS}; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 10px; font-size: 24px; font-weight: 700">{ic_barcode("currentColor", 28)}Scan barcode</a>'
           f'<section aria-label="Today\'s energy" style="background: #FFFFFF; border-radius: 18px; padding: 16px; display: flex; flex-direction: column; gap: 8px">'
           f'<span style="font-size: 24px; font-weight: 700; line-height: 30px">1,240{NB}kcal so far</span>'
           f'<div role="progressbar" aria-label="Energy eaten today" aria-valuemin="0" aria-valuemax="2000" aria-valuenow="1240" aria-valuetext="1,240 of about 2,000 kilocalories, estimate" style="height: 10px; border-radius: 5px; background: #E1E6E0; overflow: hidden"><div style="width: 62%; height: 10px; border-radius: 5px; background: {SKY}"></div></div>'
           f'<span style="font-size: 21px; color: {SOFT}; line-height: 27px">Daily guide about 2,000{NB}kcal</span></section></main>')
    nav = ('<nav aria-label="Tabs" style="position: absolute; left: 16px; right: 16px; bottom: 22px; height: 62px; border-radius: 31px; background: rgba(250,251,248,0.88); box-shadow: 0 8px 24px rgba(23,33,27,0.14), inset 0 0 0 0.5px rgba(23,33,27,0.10); display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); padding: 5px; box-sizing: border-box">'
           f'<a href="Main.dc.html" aria-current="page" aria-label="My Nuri" style="display: flex; align-items: center; justify-content: center; border-radius: 26px; background: rgba(59,106,74,0.13)">{big30(ic_globe(True, MOSS))}</a>'
           f'<a href="#" aria-label="Diary" style="display: flex; align-items: center; justify-content: center">{big30(ic_book("#5C6862"))}</a>'
           f'<a href="TodayPlan.dc.html" aria-label="Plan" style="display: flex; align-items: center; justify-content: center">{ic_walk(False, "#5C6862", 30)}</a>'
           f'<a href="#" aria-label="You" style="display: flex; align-items: center; justify-content: center">{big30(ic_person("#5C6862"))}</a></nav>')
    body = head('My Nuri — today, largest text') + frame() + big + nav + '</div>\n'
    return body + tail()

FILES = {
    'Main.dc.html': board_today, 'HomeSensitive.dc.html': board_today_sensitive, 'HomeScrolled.dc.html': board_today_scrolled,
    'HomeLargeText.dc.html': board_today_large, 'FoodSearch.dc.html': board_search, 'FoodDetail.dc.html': board_detail,
    'TodayPlan.dc.html': board_plan,
}
for name, fn in FILES.items():
    with open(os.path.join(OUT, name), 'w') as f:
        f.write(fn())
    print('wrote', name)

# ---------- sign in and first run ----------
def ic_apple(c, s=19):
    # simplified glyph for the mockup; production uses ASAuthorizationAppleIDButton
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="{c}" aria-hidden="true"><path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9-.7 0-1.8-.9-3-.8-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.3.9-1.3 1.3-2.6 1.3-2.6s-2.5-1-2.5-3.7zM14.1 5.5c.6-.8 1.1-1.8 1-2.9-.9 0-2.1.6-2.7 1.4-.6.7-1.1 1.8-1 2.8 1 .1 2.1-.5 2.7-1.3z"></path></svg>'

def ic_google_mark():
    # placeholder mark; production uses Google's official sign-in button asset
    return ('<span aria-hidden="true" style="width: 20px; height: 20px; border-radius: 10px; box-shadow: inset 0 0 0 2px #4285F4; '
            'display: inline-flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; color: #4285F4">G</span>')

def ic_mail(c, s=20):
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="1.9" stroke-linecap="round" aria-hidden="true"><rect x="3.5" y="5.5" width="17" height="13" rx="2"></rect><path d="M4 7l8 6 8-6"></path></svg>'

def board_welcome():
    body = (head('Welcome to Nuri') + frame()
            + '<main style="position: absolute; inset: 0; display: flex; flex-direction: column; padding: 59px 24px 34px 24px; box-sizing: border-box">'
            + '<div style="display: flex; flex-direction: column; align-items: center; gap: 18px; padding-top: 40px">'
            + world(196, 'An illustrated world of food groups')
            + f'<div style="display: flex; align-items: baseline; gap: 10px"><span style="font-family: \'Gowun Dodum\', sans-serif; font-size: 40px; line-height: 44px; color: {MOSS}">누리</span><span style="font-size: 22px; font-weight: 700; color: {MOSS}">Nuri</span></div>'
            + '<h1 style="margin: 0; font-size: 28px; line-height: 34px; font-weight: 700; text-align: center">Food and movement, gently</h1>'
            + f'<p style="margin: 0; font-size: 17px; line-height: 23px; color: {SOFT}; text-align: center; max-width: 320px">Log meals, watch your world grow, and get a plan that fits your week. Your data stays yours.</p></div>'
            + '<div style="margin-top: auto; display: flex; flex-direction: column; gap: 10px">'
            + f'<a href="Consent.dc.html" style="min-height: 52px; border-radius: 14px; background: #000000; color: #FFFFFF; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 17px; font-weight: 600">{ic_apple("#FFFFFF")}Continue with Apple</a>'
            + f'<a href="Consent.dc.html" style="min-height: 52px; border-radius: 14px; background: #FFFFFF; box-shadow: inset 0 0 0 1px #747775; color: #1F1F1F; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 10px; font-size: 17px; font-weight: 600">{ic_google_mark()}Continue with Google</a>'
            + f'<a href="EmailSignIn.dc.html" style="min-height: 52px; border-radius: 14px; background: #E3E8E2; color: {INK}; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 17px; font-weight: 600">{ic_mail(INK)}Continue with email</a>'
            + f'<a href="Consent.dc.html" style="min-height: 44px; display: flex; align-items: center; justify-content: center; text-decoration: none; color: {MOSS}; font-size: 17px; font-weight: 700">Use without an account</a>'
            + f'<p style="margin: 4px 0 0 0; font-size: 13px; line-height: 18px; color: {SOFT}; text-align: center">For adults 18 and over. By continuing you agree to the <a href="#">Terms</a> and <a href="#">Privacy Policy</a>.</p>'
            + '</div></main></div>\n')
    return body + tail()

def board_email():
    script = r'''class Component extends DCLogic {
  constructor(props) { super(props); this.state = { step: 'email' }; }
  renderVals() {
    const code = this.state.step === 'code';
    return {
      onEmail: !code, onCode: code,
      sendCode: () => this.setState({ step: 'code' }),
      changeEmail: () => this.setState({ step: 'email' })
    };
  }
}'''
    boxes = ''.join(f'<span style="height: 56px; border-radius: 12px; background: #FFFFFF; box-shadow: inset 0 0 0 {"2px " + SKY if i == 0 else "1px #C9D0C8"}; display: flex; align-items: center; justify-content: center; font-size: 22px; font-weight: 700"></span>' for i in range(6))
    body = (head('Sign in with email') + frame()
            + '<main style="display: flex; flex-direction: column; padding: 59px 16px 0 16px">'
            + f'<a href="Welcome.dc.html" style="align-self: flex-start; min-height: 44px; display: flex; align-items: center; gap: 2px; text-decoration: none; font-size: 17px; color: {MOSS}"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" aria-hidden="true"><path d="M15 5l-7 7 7 7"></path></svg>Back</a>'
            + '<div style="padding: 8px 4px 0 4px; display: flex; flex-direction: column; gap: 22px">'
            + f'<sc-if value="{{{{ onEmail }}}}" hint-placeholder-val="{{{{ true }}}}"><div style="display: flex; flex-direction: column; gap: 22px">'
            + f'<div style="display: flex; flex-direction: column; gap: 6px"><h1 style="margin: 0; font-size: 34px; line-height: 41px; font-weight: 700; letter-spacing: -0.4px">Sign in with email</h1>'
            + f'<p style="margin: 0; font-size: 17px; line-height: 23px; color: {SOFT}">We will send a 6-digit code. No password to remember.</p></div>'
            + f'<label style="display: flex; flex-direction: column; gap: 6px"><span style="font-size: 15px; font-weight: 600">Email</span>'
            + f'<input type="email" autocomplete="email" placeholder="you@example.com" style="height: 52px; box-sizing: border-box; border: none; border-radius: 12px; background: #FFFFFF; box-shadow: inset 0 0 0 1px #C9D0C8; padding: 0 14px; font-family: inherit; font-size: 17px; color: {INK}"></label>'
            + f'<button onClick="{{{{ sendCode }}}}" style="min-height: 52px; border: none; border-radius: 14px; background: {MOSS}; color: #FFFFFF; font-family: inherit; font-size: 17px; font-weight: 700; cursor: pointer">Send code</button></div></sc-if>'
            + f'<sc-if value="{{{{ onCode }}}}" hint-placeholder-val="{{{{ false }}}}"><div style="display: flex; flex-direction: column; gap: 22px">'
            + f'<div style="display: flex; flex-direction: column; gap: 6px"><h1 style="margin: 0; font-size: 34px; line-height: 41px; font-weight: 700; letter-spacing: -0.4px">Check your email</h1>'
            + f'<p style="margin: 0; font-size: 17px; line-height: 23px; color: {SOFT}">Enter the 6-digit code we sent to you@example.com. It works for 10 minutes.</p></div>'
            + f'<div role="group" aria-label="6-digit code" style="display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 8px">{boxes}</div>'
            + f'<a href="Consent.dc.html" style="min-height: 52px; border-radius: 14px; background: {MOSS}; color: #FFFFFF; text-decoration: none; display: flex; align-items: center; justify-content: center; font-size: 17px; font-weight: 700">Verify</a>'
            + f'<div style="display: flex; justify-content: space-between"><span style="min-height: 44px; display: flex; align-items: center; font-size: 15px; color: {SOFT}">Resend code in 0:30</span>'
            + f'<button onClick="{{{{ changeEmail }}}}" style="min-height: 44px; border: none; background: transparent; font-family: inherit; font-size: 15px; font-weight: 700; color: {MOSS}; cursor: pointer">Use a different email</button></div></div></sc-if>'
            + '</div></main></div>\n')
    return body + tail('{"$preview":{"width":390,"height":844}}', script)

def toggle_row(label, sub, key, toggle_fn, required):
    tag = f'<span style="font-size: 12px; font-weight: 700; color: {SOFT}">Required</span>' if required else ''
    return (f'<div style="padding: 12px 16px; display: flex; gap: 12px; align-items: center">'
            f'<div style="flex-grow: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 17px; font-weight: 600; display: flex; gap: 8px; align-items: baseline">{label}{tag}</span>'
            f'<span style="font-size: 13px; line-height: 18px; color: {SOFT}">{sub}</span></div>'
            f'<button role="switch" aria-checked="{{{{{key}Aria}}}}" aria-label="{label}" onClick="{{{{ {toggle_fn} }}}}" style="width: 51px; height: 31px; flex-shrink: 0; border: none; border-radius: 16px; padding: 2px; background: {{{{{key}Track}}}}; display: flex; justify-content: {{{{{key}Justify}}}}; cursor: pointer">'
            f'<span style="width: 27px; height: 27px; border-radius: 14px; background: #FFFFFF; box-shadow: 0 2px 4px rgba(23,33,27,0.25)"></span></button></div>')

def board_consent():
    script = r'''class Component extends DCLogic {
  constructor(props) { super(props); this.state = { adult: false, health: false, stats: false }; }
  renderVals() {
    const s = this.state;
    const t = (k) => ({ [k + 'Aria']: s[k] ? 'true' : 'false', [k + 'Track']: s[k] ? '#3B6A4A' : '#C9D0C8', [k + 'Justify']: s[k] ? 'flex-end' : 'flex-start' });
    const ready = s.adult && s.health;
    return Object.assign({}, t('adult'), t('health'), t('stats'), {
      flipAdult: () => this.setState({ adult: !s.adult }),
      flipHealth: () => this.setState({ health: !s.health }),
      flipStats: () => this.setState({ stats: !s.stats }),
      ready: ready, notReady: !ready
    });
  }
}'''
    body = (head('Before you start') + frame()
            + '<main style="display: flex; flex-direction: column; gap: 18px; padding: 59px 16px 0 16px">'
            + f'<header style="display: flex; flex-direction: column; gap: 4px; padding: 6px 4px 0 4px"><h1 style="margin: 0; font-size: 34px; line-height: 41px; font-weight: 700; letter-spacing: -0.4px">Before you start</h1>'
            + f'<span style="font-size: 15px; line-height: 21px; color: {SOFT}">Two things we need, one that is up to you.</span></header>'
            + '<div style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">'
            + toggle_row('I am 18 or older', 'Nuri is made for adults.', 'adult', 'flipAdult', True) + row_sep()
            + toggle_row('Store my food and activity data', 'Needed to run Nuri. This is health information, kept private and never sold or used for ads. Export or delete it anytime.', 'health', 'flipHealth', True)
            + f'<a href="#" style="min-height: 44px; padding: 0 16px; display: flex; align-items: center; justify-content: space-between; text-decoration: none; color: {INK}; font-size: 15px; border-top: 1px solid {SEP}; margin-left: 16px; padding-left: 0">What we store and why{ic_chev()}</a></div>'
            + '<div style="background: #FFFFFF; border-radius: 16px; display: flex; flex-direction: column">'
            + toggle_row('Share anonymous usage stats', 'Helps improve Nuri. Never includes foods, notes or health data.', 'stats', 'flipStats', False) + '</div>'
            + f'<p style="margin: 0 4px; font-size: 13px; line-height: 19px; color: {SOFT}">Nuri gives general wellness estimates, not medical advice. Food energy, nutrients and exercise vary by person, preparation and device. For medical or nutrition guidance, talk to a qualified clinician.</p>'
            + '</main>'
            + '<div style="position: absolute; left: 16px; right: 16px; bottom: 34px; display: flex; flex-direction: column; gap: 8px">'
            + f'<sc-if value="{{{{ ready }}}}" hint-placeholder-val="{{{{ false }}}}"><a href="Main.dc.html" style="min-height: 52px; border-radius: 14px; background: {MOSS}; color: #FFFFFF; text-decoration: none; display: flex; align-items: center; justify-content: center; font-size: 17px; font-weight: 700">Continue</a></sc-if>'
            + f'<sc-if value="{{{{ notReady }}}}" hint-placeholder-val="{{{{ true }}}}"><button disabled aria-describedby="consent-hint" style="width: 100%; min-height: 52px; border: none; border-radius: 14px; background: #D3D9D2; color: {SOFT}; font-family: inherit; font-size: 17px; font-weight: 700">Continue</button>'
            + f'<span id="consent-hint" style="font-size: 13px; color: {SOFT}; text-align: center">Turn on the two required items to continue.</span></sc-if></div></div>\n')
    return body + tail('{"$preview":{"width":390,"height":844}}', script)

AUTH = {'Welcome.dc.html': board_welcome, 'EmailSignIn.dc.html': board_email, 'Consent.dc.html': board_consent}
for name, fn in AUTH.items():
    with open(os.path.join(OUT, name), 'w') as f:
        f.write(fn())
    print('wrote', name)
