import sys
import os
from pptx import Presentation
from pptx.util import Inches, Pt

def create_pptx(markdown_text, output_path):
    prs = Presentation()
    
    # Split by slides (--- or ##)
    slides_content = markdown_text.split('\n## ')
    
    # First slide (Title)
    title_slide_layout = prs.slide_layouts[0]
    slide = prs.slides.add_slide(title_slide_layout)
    title = slide.shapes.title
    subtitle = slide.placeholders[1]
    
    first_part = slides_content[0].split('\n', 1)
    title.text = first_part[0].replace('# ', '').strip()
    if len(first_part) > 1:
        subtitle.text = first_part[1].strip()
    
    # Subsequent slides
    for content in slides_content[1:]:
        bullet_slide_layout = prs.slide_layouts[1]
        slide = prs.slides.add_slide(bullet_slide_layout)
        
        parts = content.split('\n', 1)
        slide.shapes.title.text = parts[0].strip()
        
        if len(parts) > 1:
            body_shape = slide.placeholders[1]
            tf = body_shape.text_frame
            tf.text = ""
            
            lines = parts[1].split('\n')
            for line in lines:
                line = line.strip()
                if not line: continue
                
                p = tf.add_paragraph()
                p.text = line.replace('- ', '').replace('* ', '').strip()
                # Simple indentation based on spaces (optional)
                if line.startswith('  '):
                    p.level = 1
                elif line.startswith('    '):
                    p.level = 2
    
    prs.save(output_path)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python script.py <markdown_file> <output_pptx>")
        sys.exit(1)
        
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        md = f.read()
    
    create_pptx(md, sys.argv[2])
