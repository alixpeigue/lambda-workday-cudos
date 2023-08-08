# lambda-workday-cudos

## Script de déploiement de l'infrastructure nécéssaire à la liaison entre CUDOS et Workday

Ce script déploie une fonction lambda, et une instande PostgreSQL dans RDS, les place dans un vpc commun.
De manière quitidienne, la lambda contacte l'API Workday, ce qui lui permet de synchroniser dans la base de donnée le nom du projet, la communauté, l'entreprise à partir du ProjectID.

Vérifier que le requirements.txt est à jour : `pip freeze > requirements.txt` (utiliser un virtualenv).

Découvrir et récupérer les modules `terraform get`
Initialiser terraform `terraform init`
Déployer `terraform apply`