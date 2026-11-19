#!/usr/bin/env python3
"""Generates PetTrack/Resources/Localizable.xcstrings and InfoPlist.xcstrings from tools/translations.py."""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from translations import T  # noqa: E402

LANGS = ["es", "de", "fr", "nl"]

INFO_PLIST = {
    "CFBundleDisplayName": ("PetTrack", "PetTrack", "PetTrack", "PetTrack"),
    "NSCameraUsageDescription": (
        "PetTrack usa la cámara para escanear informes veterinarios y hacer fotos de tu mascota.",
        "PetTrack nutzt die Kamera, um Tierarztberichte zu scannen und Fotos deines Tieres aufzunehmen.",
        "PetTrack utilise l'appareil photo pour scanner les comptes rendus vétérinaires et photographier votre animal.",
        "PetTrack gebruikt de camera om dierenartsrapporten te scannen en foto's van je huisdier te maken.",
    ),
    "NSPhotoLibraryUsageDescription": (
        "PetTrack te permite elegir fotos de tu mascota y de informes veterinarios.",
        "PetTrack lässt dich Fotos deines Tieres und von Tierarztberichten auswählen.",
        "PetTrack vous permet de choisir des photos de votre animal et de comptes rendus vétérinaires.",
        "Met PetTrack kun je foto's van je huisdier en van dierenartsrapporten kiezen.",
    ),
}


def catalog(table):
    strings = {}
    for key in sorted(table):
        values = table[key]
        strings[key] = {
            "localizations": {
                lang: {"stringUnit": {"state": "translated", "value": value}}
                for lang, value in zip(LANGS, values)
            }
        }
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def write(name, table):
    path = os.path.join(ROOT, "PetTrack", "Resources", name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(catalog(table), f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"wrote {path} ({len(table)} keys)")


if __name__ == "__main__":
    for key, values in T.items():
        assert len(values) == 4, key
    write("Localizable.xcstrings", T)
    write("InfoPlist.xcstrings", INFO_PLIST)
