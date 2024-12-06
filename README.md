# Niveles de Aislamiento de Transacciones en PostgreSQL

Este archivo proporciona una descripción de los niveles de aislamiento de transacciones en PostgreSQL y ejemplos de cómo configurarlos y utilizarlos dentro de las bases de datos.

## Introducción

En PostgreSQL, las transacciones pueden configurarse con diferentes niveles de aislamiento. Estos niveles determinan cómo las transacciones concurrentes interactúan entre sí, y controlan la visibilidad de los cambios realizados en una transacción para otras transacciones. Los niveles de aislamiento son fundamentales para garantizar la consistencia y la integridad de los datos en un entorno de bases de datos con múltiples transacciones concurrentes.

## Niveles de Aislamiento en PostgreSQL

PostgreSQL soporta los siguientes niveles de aislamiento de transacciones:

### 1. **Read Uncommitted**
   - **Descripción**: Este nivel de aislamiento permite leer datos no confirmados de otras transacciones. No es totalmente soportado por PostgreSQL, ya que siempre se comporta como **Read Committed**.
   - **Uso**: A pesar de estar en el estándar SQL, este nivel no tiene un impacto real en PostgreSQL.

### 2. **Read Committed** (Predeterminado)
   - **Descripción**: En este nivel, una transacción puede leer solo datos que hayan sido confirmados por otras transacciones. Si una transacción está modificando una fila, cualquier otra transacción que lea esa fila no verá los cambios hasta que la transacción se confirme.
   - **Uso**: Este es el nivel predeterminado en PostgreSQL. No previene las lecturas sucias pero evita que se lean datos no confirmados.
   - **Comando para configurar**:
     ```sql
     SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
     ```

### 3. **Repeatable Read**
   - **Descripción**: Asegura que todas las lecturas realizadas durante la transacción verán los mismos datos, incluso si otras transacciones modifican esos datos. Esto evita las lecturas fantasmas, pero puede permitir ciertos tipos de "non-repeatable reads" (lecturas no repetibles).
   - **Uso**: Proporciona una mayor consistencia, pero puede bloquear más filas debido a las restricciones de lectura.
   - **Comando para configurar**:
     ```sql
     SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
     ```

### 4. **Serializable**
   - **Descripción**: Es el nivel de aislamiento más estricto. En este nivel, las transacciones se ejecutan como si fueran serializadas, lo que significa que el resultado de la ejecución de todas las transacciones concurrentes es equivalente a ejecutar las transacciones una después de otra.
   - **Uso**: Proporciona la mayor consistencia pero puede generar más bloqueos y reduce el rendimiento en sistemas con alta concurrencia.
   - **Comando para configurar**:
     ```sql
     SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
     ```

## Comandos para Configurar Niveles de Aislamiento

### **Establecer nivel de aislamiento al crear una transacción**
   - Cuando inicias una transacción, puedes especificar el nivel de aislamiento:
     ```sql
     BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
     -- Realiza las operaciones dentro de la transacción
     COMMIT;
     ```

### **Cambiar el nivel de aislamiento en una transacción en curso**
   - Si ya tienes una transacción abierta, puedes cambiar el nivel de aislamiento dentro de la misma:
     ```sql
     SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
     ```

## Ejemplo de uso

### **Ejemplo 1: Read Committed**
   - Transacción 1:
     ```sql
     BEGIN;
     SELECT * FROM products;
     -- Realiza cambios en la base de datos
     COMMIT;
     ```
   - Transacción 2 (lectura de datos de la transacción 1):
     ```sql
     BEGIN;
     SELECT * FROM products;
     COMMIT;
     ```

### **Ejemplo 2: Repeatable Read**
   - Transacción 1:
     ```sql
     BEGIN;
     SELECT * FROM products WHERE id = 1;
     -- Realiza cambios en la base de datos
     COMMIT;
     ```
   - Transacción 2 (lectura de datos de la transacción 1):
     ```sql
     BEGIN;
     SELECT * FROM products WHERE id = 1;
     COMMIT;
     ```

### **Ejemplo 3: Serializable**
   - Transacción 1:
     ```sql
     BEGIN;
     SELECT * FROM accounts WHERE balance > 1000;
     -- Realiza cambios en la base de datos
     COMMIT;
     ```
   - Transacción 2 (intentando leer los mismos datos):
     ```sql
     BEGIN;
     SELECT * FROM accounts WHERE balance > 1000;
     COMMIT;
     ```

## Conclusión

Los niveles de aislamiento de transacciones son una herramienta poderosa para controlar el comportamiento de las transacciones concurrentes en PostgreSQL. Dependiendo de los requisitos de consistencia y rendimiento de la aplicación, puedes elegir el nivel adecuado para cada situación. Sin embargo, debes tener en cuenta que los niveles de aislamiento más altos, como **Serializable**, pueden tener un impacto en el rendimiento debido a la mayor cantidad de bloqueos y restricciones.

## Recursos Adicionales

- [Documentación oficial de PostgreSQL - Control de concurrencia](https://www.postgresql.org/docs/current/transaction-iso.html)
- [Documentación oficial de PostgreSQL - SET TRANSACTION](https://www.postgresql.org/docs/current/sql-set-transaction.html)

