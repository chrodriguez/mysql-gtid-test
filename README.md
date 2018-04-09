# Prubas de concepto con Replicacion Mysql

El siguiente ejemplo muestra esquemas de replicación basados en MySQL usando
GTID. Usando GTIDs, cambia la forma en que un esclavo apunta al master. Antes se
usaba master_file y master_pos que apuntaban al binary log y posición en él.
Ahora, los GTID son valores con el formato `UUID_SERVER:TRANSACTION_ID`. 
Como ahora los GTID son únicos, los esclavos reciben el GTID de la transacción
original, y en caso que un servidor master muera, y se promueva un esclavo como
maestro, los otros esclavos (si existieran), simplemente apuntan al nuevo
maestro y no es necesario averiguar las posiciones dentro de los binary logs y
archivos del nuevo maetsro.

## Notas

* Los ejemplos asumen el proyecto donde se prueban los contenedores con
docker-compose se llama mysql-gtid
* Para inicializar un proyecto a cero correr los siguiente comandos:

```
docker-compose down
docker volume rm mysqlgtid_one mysqlgtid_two mysqlgtid_three\
  mysqlgtid_master1 mysqlgtid_slave-all 
```

* Para inicializar el stack completo:

```
docker-compose up -d
```


## Arquitectura de la prueba

La arquitectura es como muestra el siguiente gráfico:

```
                +----------+    +----------+    +----------+
                |   one    |    |   two    |    |  three   |
                | (master) |<---|  (slave) |<---|  (slave) |
                +----------+    +----------+    +----------+
                     ^
                     |
                     |
+----------+    +----------+
|  master1 |    |slave-all |
| (master) |<---| (slave)  |
+----------+    +----------+
```

O sea que **one** es master. **two** slave de **one** y **three** slave de
**two**.
Luego **master1** otro master. **slave-all** es un esclavo multi master, esto
es, es esclavo de **one** y **master1**

## Las Pruebas

1. Inicializar las configuraciones
    1. Se incializan los masters
    1. Se inciializan los esclavos
    1. Se verifica que los esclavos estén funcionando
2. Sacamos de servicio a **two**
    1. Analizamos el estado de **three**
    1. Cambiamos el master que apunta **three**

### Inicializar las configuraciones

Primero creamos el usuario de replicación en **one** y **master1**:

```
docker-compose exec one mysql -pone
```

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY 'pass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
exit
```

```
docker-compose exec master1 mysql -pmaster1
```

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY 'pass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
exit;
```

Cargar dumps de prueba en ambas dbs para realizar las pruebas. Asumimos las
siguientes bases de datos:

* **En one:** se crean las dbs `one_people` y `one_cities`
* **En master1:** se crean `master1_countries` y `master1_subjects`


Todas con las siguientes estructuras:

```sql
-- Dumps para one

DROP DATABASE IF EXISTS one_people;
CREATE DATABASE one_people;
USE one_people;
CREATE TABLE `people` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
   `lastname` varchar(255) NOT NULL,
  `firstname` varchar(255) NOT NULL,
  `identification_type` int(11) DEFAULT NULL,
  `identification_number` varchar(20) DEFAULT NULL,
  `sex` int(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`)
);
INSERT INTO people(lastname, firstname, identification_type,
  identification_number) VALUES
  ('Perez', 'Juan', 1, 1111),
  ('Gomez','Jose',1,2222),
  ('Rodriguez','Maria',1,3333);

DROP DATABASE IF EXISTS one_cities;
CREATE DATABASE one_cities;
USE one_cities;
CREATE TABLE `cities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `short_name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
);
INSERT INTO cities(name,short_name) VALUES
  ('La Plata','LP'),
  ('Capital Federal','CF');

-- Dumps para master1

DROP DATABASE IF EXISTS master1_countries;
CREATE DATABASE master1_countries;
USE master1_countries;
CREATE TABLE `countries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
);
INSERT INTO countries(name) VALUES
  ('Argentina'),
  ('Bolivia'),
  ('Paraguay');

DROP DATABASE IF EXISTS master1_subjects;
CREATE DATABASE master1_subjects;
USE master1_subjects;
CREATE TABLE `subjects` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `fantasy_name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
);
INSERT INTO subjects(name, fantasy_name) VALUES
  ('Matematicas', 'Mate'),
  ('Lengua','Lengua y Literatura');

```

*Estos archivos ya existen en el directorio `sql/*sql`*

#### Inicializamos los master

Asumiendo el dump para one se llama `one.sql` y el de master1 se llama
`master1.sql`, entonces:

```
docker exec -i mysqlgtid_one_1 mysql -pone < sql/one.sql
docker exec -i mysqlgtid_master1_1 mysql -pmaster1 < sql/master1.sql
```

#### Inicializamos los esclavos

##### Arrancamos primero por **two** 

Debemos descargar los datos desde **one** para inicializar **two**:

```
docker exec mysqlgtid_one_1 mysqldump -pone --all-databases \
  --flush-privileges --single-transaction --flush-logs --triggers \
  --routines --events --hex-blob > tmp/one-dump.sql
```

La siguiente instrucción, nos va a permitir poder cargar un dump que trae
información del GTID del master:

```
docker-compose exec two mysql -ptwo
```

```sql
reset master;
exit;
```

Luego, cargamos el dump one-dump.sql en two:

```
docker exec -i mysqlgtid_two_1 mysql -ptwo < tmp/one-dump.sql
```

Conectamos luego con two, para inicializar el esclavo. *Observar que la clave 
de two es one luego de cargar el dump*

```
docker-compose exec two mysql -pone
```

```sql
change master to master_host='one', master_user='repl', \
  master_password='pass', master_auto_position=1;
start slave;
show slave status \G
```

##### Inicializamos **three** a partir de **one**

Debemos descargar los datos desde **two** para inicializar **three**:

```
docker exec mysqlgtid_two_1 mysqldump -pone --all-databases \
  --flush-privileges --single-transaction --flush-logs --triggers \
  --routines --events --hex-blob > tmp/two-dump.sql
```

La siguiente instrucción, nos va a permitir poder cargar un dump que trae
información del GTID del master:

```
docker-compose exec three mysql -pthree
```

```sql
reset master;
exit;
```

Luego, cargamos el dump two-dump.sql en two:

```
docker exec -i mysqlgtid_three_1 mysql -pthree < tmp/two-dump.sql
```

Conectamos luego con three, para inicializar el esclavo. *Observar que la clave 
de two es one luego de cargar el dump*

```
docker-compose exec three mysql -pone
```

```sql
change master to master_host='two', master_user='repl', \
  master_password='pass', master_auto_position=1;
start slave;
show slave status \G
```

#### Inicializamos **slave-all** a partir de **one** y **master1**

Esta es la configuración más compleja, porque tenemos dos master diferentes y
para ello, debemos usar canales. Cada canal de un esclavo multi source, mantiene
los GTID del master correspondiente para cada canal. Por ello, solo para
inicializar el esclavo, los dumps serán parciales de los respectivos master,
teniendo así que usar entonces la opción de mysqldump `--set-gtid-purged=OFF`.

##### Descargamos los dumps de **one** y **master1**

```
docker exec mysqlgtid_one_1 mysqldump -pone --databases one_people one_cities \
  --flush-privileges --single-transaction --flush-logs --triggers   \
  --routines --events --hex-blob --set-gtid-purged=OFF > tmp/one_slave-all.sql

docker exec mysqlgtid_master1_1 mysqldump -pmaster1 --databases master1_countries \
  master1_subjects --flush-privileges --single-transaction --flush-logs \
  --triggers   --routines --events --hex-blob \
  --set-gtid-purged=OFF > tmp/master1-slave-all.sql
```

##### Cargamos los dumps en slave-all

```
docker exec -i mysqlgtid_slave-all_1 mysql -pslave < tmp/one_slave-all.sql
docker exec -i mysqlgtid_slave-all_1 mysql -pslave < tmp/master1-slave-all.sql
```

##### Preparamos al esclavo multi source

Tenemos que resetear los GTID, y apuntar a los respectivos masters, para ello
corremos los siguientes comandos:

```sql
reset master;
change master to master_host='one', master_user='repl', \
  master_password='pass', master_auto_position=1 for channel 'one';
change master to master_host='master1', master_user='repl', \
  master_password='pass', master_auto_position=1 for channel 'master1';
set global \
  gtid_purged='6bdc251f-3c20-11e8-846f-0242ac1a0005:1-29,6ab4e989-3c20-11e8-8e7f-0242ac1a0003:1-49';
start slave for channel 'one';
start slave for channel 'master1';
show slave status \G
```
**OJO**: *Notar que los valores de los gtid enviados arriba se obtienen de la siguiente
salida:*

```
docker-compose exec master1 mysql -pmaster1 -e 'show master status' \
  && docker-compose exec one mysql -pone -e 'show master status'
```

#### Verificaciones

* Probar insertar, eliminar o modificar algo en **one** y analizar como quedan los datos
  en:
  * **two**
  * **three**
  * **slave-all**
* probar insertar, eliminar o modificar algo en **master1** y analizar como
  quedan los datos en **slave-all**

#### Apagar two y mover three para que apunte a one

Apagamos **two**:

```
docker-compose stop two
```

Verificamos como queda **three**:

```
docker-compose exec three mysql -pone -e 'show slave status \G'
```

Seguramente veamos algo como:

```
Slave_IO_State: Reconnecting after a failed master event read
```

Entonces, simplemente cambiamos el master para que apunte al nuevo, pero antes
de hacerlo, insertamos un dato o modificamos algo en **one**:

```
docker-compose exec one mysql -pone one_cities

```

```sql
insert into cities(name,short_name) values('Chascomus','CH');
```

**Verificar que no están los datos en three**

Ahora, cambiamos el master de **three**:

```
stop slave;
change master to master_host='one', master_user='repl', \
  master_password='pass', master_auto_position=1;
start slave;
show slave status \G
```

**Voilà**
