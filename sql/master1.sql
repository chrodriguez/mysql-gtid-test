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

