# lambda-workday-cudos

### Script de déploiement de l'infrastructure nécéssaire à la liaison entre CUDOS et Workday

## Déploiement

### Paramétrer le déploiement

Les paramètres modifiables sont regroupées dans les locals du [main.tf](main.tf) :
- **vpc_cidr**: le CIDR de VPC dans lequel seront placées la base de données et la fonction réceptrice (voir [Architecture](#architecture))
- **azs**: Les zones de disponibilité dans lesquelles déployer le VPC
- **region**: la région de déploiement
- **quicksight_secretsmanager_role**: le rôle avec lequel est configuré quicksight pour accéder aux informations de connexion de la base de données
- **quicksight_group**: l'ARN du groupe quicksight qui seraz autorisé à accéder à la Data Source et au Data Set créés
- **quicksight_region_cidr**: le CIDR de quicksight pour la région de déploiement (voir [AWS Regions, websites, IP address ranges, and endpoints](https://docs.aws.amazon.com/quicksight/latest/user/regions.html))

### Commandes

 - Découvrir et récupérer les modules `terraform get`
 - Initialiser terraform `terraform init`
 - Déployer `terraform apply` le premier apply peut ne pas marcher, dans ce cas, appliquer une seconde fois.

## Architecture

Ce script déploie l'architecture suivante :

![alt Schéma d'architecture](assets/architecture.jpg?raw=true "Architecture")

L'objectif de cette architecture est de compléter les dashboards CUDOS en apportant des informations issues de Workday dans le dashboard. Ce script déploie ces ressources :

### Lambda émettrice

Cette fonction lambda est déclenchée toutes les 24 heures. Son but est de contacter l'api de Workday pour obtenir les informations sur tous les projets gérés par workday. Les informations que l'on souhaite obtenir pour chaque projet sont :
- project_name
- project_owner
- community
- client
    
La fonction doit aussi récupérer les informations de connexion à la base de donnée RDS (username et mot de passe) dans un secret Secrets Manager. Ces informations sont ensuites envoyées dans une sqs au format JSON

Les informations fournies à la fonction par les variables d'environnement sont :
- sqs: l'url de la queue
- secret: l'ARN du secret
- region: la région AWS

Le JSON placé dans la SQS doit suivre le schéma suivant :
```json
{
    "credentials": {
        "username": "myUserName",
        "password": "myPassword"
    },
    "data": [
        {
            "projectID": "myProjectID",
            "owner": "myProjectOwner"
            ...
        },
        ...
    ]
}
```

### Lambda réceptrice

Le rôle de cette fonction est de récupérer les données placées dans la queue par la [fonction émettrice](#lambda-émettrice) et de les palcer dans la base de données. Elle crée aussi la table si celle-ci n'est pas encore créée.

Les informations fournies à la fonction par les variables d'environnement sont :
- dbname: le nom de la base de données
- host: l'adresse de la db
- port: le port utilisé
- region: la région AWS

Le schméma de la table créée est :
```sql
CREATE TABLE IF NOT EXISTS workday (
    ProjectID VARCHAR(10) PRIMARY KEY,
    name TEXT
)
```

### Base de données PostgresSQL sur RDS

On déploie une base PostgreSQL sur RDS pour stocker les données répliquées de Workday. Les information de connexion à cette base sont stockées dans un secret Secrets Manager.

## Quicksight

Afin de pouvoir accéder aux données stockées dans cette base, la script déploie les resources suivantes :
- Une connexion VPC
- Une data source

## A faire

Actuellement, la lambda emitter (voir [Lambda émettrice](#lambda-émettrice)) ne contacte pas l'API Workday mais une API mockup de test. Il faut donc mettre en palce les appels à cette API, ainsi que gérer de manière sécurisée les clés d'accès à l'API Workday.

La [lambda réceptrice](#lambda-réceptrice) récupère les données dans la SQS et les place dans la base de données, mais ne fait aucune validation des données. Il fut donc mettre en place un système de validations des données recues afin de s'assurer de la bonne communication entre les deux fonctions lambda.