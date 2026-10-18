import sys, fitz
doc = fitz.open(r'C:\Users\HP\Desktop\VERIPROF\EduQuali - Presentation.pdf')
for n in sys.argv[1:]:
    doc[int(n) - 1].get_pixmap(dpi=96).save(f'v{n}.png')
    print('rendu', n)
