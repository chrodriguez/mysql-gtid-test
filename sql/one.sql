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


