USE employees;

flush /*!50503 binary */ logs;

SELECT 'LOADING employees_extra' as 'INFO';
source load_employees_extra.dump;
