#!/usr/bin/env python3
"""
PDF Unlocker & Text Extractor
Decrypts a password-protected PDF and extracts all text.
Returns the extracted text to the caller (Chaquopy MethodChannel).

Usage (CLI):
    python pdf_unlock.py <input.pdf> <password>
"""

import sys
import os
from pypdf import PdfReader, PdfWriter


def unlock_and_extract(input_path: str, password: str) -> str:
    """
    Decrypts a PDF and extracts all text from it.
    Returns the full extracted text as a string.
    Raises FileNotFoundError if input doesn't exist.
    Raises ValueError if password is wrong.
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    reader = PdfReader(input_path)

    if reader.is_encrypted:
        result = reader.decrypt(password)
        if result == 0:
            raise ValueError("Incorrect password")

    # Extract text from all pages using pypdf (works on Android, no pdftotext needed)
    text = ""
    page_count = 0
    for page in reader.pages:
        page_text = page.extract_text() or ""
        text += page_text + "\n"
        page_count += 1

    return text.strip()


def unlock_pdf(input_path: str, password: str, output_path: str = None) -> str:
    """Legacy function: decrypts and saves an unlocked copy."""
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    if output_path is None:
        base, ext = os.path.splitext(input_path)
        output_path = f"{base}_unlocked{ext}"

    reader = PdfReader(input_path)

    if not reader.is_encrypted:
        pass
    else:
        result = reader.decrypt(password)
        if result == 0:
            raise ValueError("Incorrect password")

    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)

    with open(output_path, "wb") as out_file:
        writer.write(out_file)

    return output_path


def main():
    if len(sys.argv) < 3:
        sys.exit(1)

    input_pdf = sys.argv[1]
    password = sys.argv[2]

    text = unlock_and_extract(input_pdf, password)
    print(text)


if __name__ == "__main__":
    main()
