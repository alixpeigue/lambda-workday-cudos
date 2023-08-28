# lambda-workday-cudos

### Script de déploiement de l'infrastructure nécéssaire à la liaison entre CUDOS et Workday

## Déploiement

### Paramétrer le déploiement

Les paramètres modifiables sont regroupées dans les locals du [main.tf](main.tf) :
- **vpc_cidr**: le CIDR du VPC dans lequel seront placées la base de données et la fonction réceptrice (voir [Architecture](#architecture))
- **azs**: Les zones de disponibilité dans lesquelles déployer le VPC
- **region**: la région de déploiement
- **quicksight_secretsmanager_role**: le rôle avec lequel est configuré quicksight pour accéder aux informations de connexion de la base de données
- **quicksight_group**: l'ARN du groupe quicksight qui sera autorisé à accéder à la Data Source et au Data Set créés
- **quicksight_region_cidr**: le CIDR de quicksight pour la région de déploiement (voir [AWS Regions, websites, IP address ranges, and endpoints](https://docs.aws.amazon.com/quicksight/latest/user/regions.html))

### Commandes

- Découvrir et récupérer les modules `terraform get`
- Initialiser terraform `terraform init`
- Déployer `terraform apply` le premier apply peut ne pas marcher, dans ce cas appliquer une seconde fois.

### Vérifier que le déploiement à bien fonctionné

- Le deploy terraform n'a pas fait d'erreurs
- Dans la console, se rendre sur la lambda `workday-cudos-replication-emitter-lambda`
- Dans tester, cliquer sur tester, l'exécution de la fonction doit réussir
- Se rendre dans les logs de la lambda `workday-cudos-replication-receiver-lambda`
- Vérifier qu'un flux de journal daté de l'heure de lancement de la fonction émettrice est présent. Ses contenus devraient contenir :
  - "Data parsed : [Project(id="1", ...), ...]
  - connected
  - table created
  - values inserted
  - table : ***Les données correspondant à la ligne data parsed sous la forme de tuples liste de tuples [(id, ...), ... ]***
  - Done !
- Se rendre sur quicksight avec un compte ayant accès aux data sources (dans le groupe donné en paramètres)
  - créer une nouvelle analyse
  - vérifier que l'on peut choisir workday-data-set
  - cliquer sur use in analysis, puis create
  - vérifier que la fields list correspond bien aux champs suivants :
    - id
    - name
    - owner
    - community
    - company
  - vous pouvez vérifier qui les données sont bien présentes en insrant par exemple un tableau

## Architecture

Ce script déploie l'architecture suivante :

![alt Schéma d'architecture](assets/architecture.jpg?raw=true "Architecture")

L'objectif de cette architecture est de compléter les dashboards CUDOS en apportant des informations issues de Workday dans le dashboard.

### Lambda émettrice

Cette fonction lambda est déclenchée toutes les 24 heures. Son but est de contacter l'api de Workday pour obtenir les informations sur tous les projets gérés par workday. Les informations que l'on souhaite obtenir pour chaque projet sont :
- name
- owner
- community
- company
    
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
            "id": "myProjectID",
            "owner": "myProjectOwner"
            ...
        },
        ...
    ]
}
```

### Lambda réceptrice

Le rôle de cette fonction est de récupérer les données placées dans la queue par la [fonction émettrice](#lambda-émettrice) et de les placer dans la base de données. Elle crée aussi la table si celle-ci n'est pas encore créée.

Les informations fournies à la fonction par les variables d'environnement sont :
- dbname: le nom de la base de données
- host: l'adresse de la db
- port: le port utilisé
- region: la région AWS

Le schéma de la table créée est :
```sql
CREATE TABLE IF NOT EXISTS workday (
    id VARCHAR(15) PRIMARY KEY,
    name TEXT,
    owner TEXT,
    community TEXT,
    company TEXT
)
```

### Base de données PostgreSQL sur RDS

On déploie une base PostgreSQL sur RDS pour stocker les données répliquées de Workday. Les information de connexion à cette base sont stockées dans un secret Secrets Manager.

### Quicksight

Afin de pouvoir accéder aux données stockées dans cette base, le script déploie les resources suivantes :
- Une connexion VPC au VPC de la db
- Une data source qui utilise le RDS
- Un data set qui spécifie l'utilisation de la table `workday`

## A faire

- Actuellement, la lambda emitter (voir [Lambda émettrice](#lambda-émettrice)) ne contacte pas l'API Workday mais une API mockup de test. Il faut donc mettre en place les appels à la véritable API, ainsi que gérer de manière sécurisée les tokens et/ou identifiants Workday.

- La [lambda réceptrice](#lambda-réceptrice) récupère les données dans la SQS et les place dans la base de données, mais ne fait aucune validation des données. Il faut donc mettre en place un système de validation des données reçues afin de s'assurer de la bonne communication entre les deux fonctions lambda.

- Pour des raisons de coût, il a été décidé de ne pas mettre un 2e VPC endpoint pour que la lambda réceptrice accède à secrets manager, mais de transmettre les credentials dans la queue depuis la lambda émettrice. La queue est chiffrée, mais cela reste une mauvaise pratique de transmettre des informations sensibles par SQS. Ainsi, on pourrait mettre en place un VPC Endpoint pour Secrets Manager dans le VPC pour éviter une telle transmission. S'il est critique de réduire les coûts, il serait possible de mettre en place un système qui crée les endpoints pour SQS et Secrets Manager à la demande, quand la fonction émettrice est invoquée, et qui détruirait ces resources après leur utilisation.

## Bugs connus

- Erreur `Error: creating Lambda Event Source Mapping (arn:aws:sqs:eu-west-3:135225040694:worday-replication-queue): InvalidParameterValueException: Function does not exist` au premier apply -> appliquer une seconde fois
- Impossible de destroy la vpc connection dans quicksight puis de la recréer tout de suite après, celle-ci met plusieurs heures à se supprimer -> changer le `vpc_connection_id`