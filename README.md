# SFAIT Remote Assistant

## Présentation
SFAIT Remote Assistant est une application pensée pour simplifier et sécuriser les sessions d’assistance à distance destinées à notre clientèle. Conçue sur la base robuste de l’architecture RustDesk, elle permet une prise en main fluide et rapide de n’importe quel poste, où que vous soyez en France, via une connexion chiffrée de bout en bout. Le tout repose sur notre propre infrastructure, hébergée en interne, garantissant ainsi confidentialité, performance… et un contrôle obsessionnel de notre part (mais dans le bon sens, promis).

## Conditions d’utilisation

Aucunes ? Utilisez-le comme bon vous semble, tant que cela est possible.

### Avec toute notre passion (et un peu de caféine),
L’équipe de développement SFAIT ☕👨‍💻

## Windows
Le dépôt permet maintenant de produire deux variantes Windows à partir du même code source :

- `SFAIT_Remote_Assistant_portable.exe` pour lancer l’application en mode portable
- `SFAIT_Remote_Assistant_installer.msi` pour une installation Windows classique

Dans la GUI Windows, l’écran d’installation permet aussi de choisir `Run without install` pour basculer sans installation définitive.

Pour générer localement le portable et le vrai installeur MSI :

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-installer.ps1
```

Pour exporter les artefacts locaux vers `Téléchargements` avec horodatage :

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-windows-artifacts.ps1
```
