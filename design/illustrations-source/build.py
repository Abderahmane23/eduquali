# -*- coding: utf-8 -*-
"""Genere les illustrations servies a partir des PNG sources.

Deux hauteurs (200 px, et 400 px pour les ecrans denses), largeur libre :
les cadrages different d'une image a l'autre et aucune n'est recadree.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'frontend', 'web', 'public', 'img')

# fichier source -> nom utilise par les parcours
MAP = {
    'welcome.png': 'welcome',
    'verified.png': 'verified',
    'teacher.png': 'teacher',
    'find-teacher.png': 'find-teacher',
    'home_course.png': 'home-course',
    'school.png': 'school',
    'teenager.png': 'teenager',
}

HEIGHTS = {'': 200, '@2x': 400}


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for src, name in sorted(MAP.items()):
        path = os.path.join(HERE, src)
        if not os.path.exists(path):
            print('  absent, ignore : ' + src)
            continue
        img = Image.open(path).convert('RGB')
        for suffix, height in HEIGHTS.items():
            width = max(1, int(round(img.width * height / float(img.height))))
            out = img.resize((width, height), Image.LANCZOS)
            dest = os.path.join(OUT, '%s%s.webp' % (name, suffix))
            out.save(dest, 'WEBP', quality=82, method=6)
            size = os.path.getsize(dest) / 1024.
            total += size
            print('  %-22s %4dx%-4d %6.1f Ko'
                  % (os.path.basename(dest), width, height, size))
    print('total %.0f Ko' % total)


if __name__ == '__main__':
    main()
