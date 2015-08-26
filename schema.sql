--
-- Schema for CDD database.
--
-- Raw XML output for a given sequence is stored in the raw_output table.
-- JSON-formatted parsed output from rpsbproc otuput is stored in the parsed_output table.
-- Highly parsed specfic hits coming from concise redundancy processing is stored in the domain_coverage table
--
-- Redundancy values are 'C' - concise; 'S' - standard; 'F' - full.

drop table if exists raw_output;
create table raw_output
(
    md5 varchar(32) PRIMARY KEY,
    data_file varchar(255)
) engine innodb;

drop table if exists parsed_output;
create table parsed_output
(
    md5 varchar(32) primary key,
    redundancy char,
    value text
) engine innodb;

drop table if exists domain_coverage;
create table domain_coverage
(
    md5 varchar(32) primary key,
    domains text
) engine innodb; 

drop table if exists update_batch;
create table update_batch
(
    id integer auto_increment,
    success integer,
    status text,
    creation_date timestamp default current_timestamp,
    completion_date timestamp,
    primary key (id)
) engine innodb;
