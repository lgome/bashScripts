
#!/bin/bash
TO_ADDRESS="lgomez@aligntech.com"
FROM_ADDRESS="lgomez@aligntech.com"
SUBJECT="hola mundo"
BODY="esto es una prueba"
echo ${BODY} | mail -s ${SUBJECT} ${TO_ADDRESS} -- -r ${FROM_ADDRESS}

 
