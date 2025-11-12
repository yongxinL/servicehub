# Confluence

## Key Components
- the agent need to be add in the docker image for activating the Confluence and its plugins
- use agent to generate the License key
- Backdoor/Emergency URL for Confluence: https://www.onelijia.com/login.action?backdoor=true

## MySQL as backend
- due to license issue, the JDBC driver for MySQL need to be add into docker image when building
- adding database connection string in docker-compose.yam.
  ```
    - ATL_DB_TYPE=mysql
    - ATL_JDBC_URL=jdbc:mysql://host.docker.internal:9986/svchubkinora?serverTimezone=Australia/Sydney
    - ATL_JDBC_USER=dbservices
    - ATL_JDBC_PASSWORD=<password>
  ```
- create database and grant permission in MySQL

```MySQL
DROP DATABASE svchubkinora;
CREATE DATABASE svchubkinora CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
GRANT ALL PRIVILEGES ON svchubkinora.* TO 'dbservices'@'172.61.128.%' IDENTIFIED BY '<password>';
```

## PostgreSQL as backend
- PostgreSQL drver has bundled in docker image, no extra driver installed required.
- adding database connection string in docker-compose.yam.
  ```
    - ATL_DB_TYPE=postgresql
    - ATL_JDBC_URL=jdbc:postgresql://postgresql:5432/svchubkinora
    - ATL_JDBC_USER=dbservice
    - ATL_JDBC_PASSWORD=
  ```
- create database and grant permission in PostgreSQL
  ```SQL
  >> psql -U dbservice
  DROP DATABASE svchubkinora;
  CREATE USER dbservice WITH PASSWORD '3b3251d22f4fd2b19a';
  CREATE DATABASE svchubkinora;
  GRANT ALL PRIVILEGES ON DATABASE svchubkinora TO dbservice;
  ```

## Activation
- use below command to generate the key for Confluence
  ```
  docker exec -it <containerID> /bin/bash

  java -jar /opt/atlassian/confluence/bin/atlassian-agent.jar -d -m confluence@atlassian.com -p conf -o oneLiJIA -s B836-9R3J-BUA5-XMAI
  ```
  - p > product,  conf = confluence
  - o > server address,  in my case, it's Lifamy.com
  - m > mailbox
  - n > account name
  - s > server ID

 Confluence for BC1N-U3CS-ZX0P-JK95, Entitlement Number: SEN-L1757681723749
```
AAABng0ODAoPeJx1UdFuozAQfPdXIN3jiRRMiJNIlq41VJc7IE2dRNW9OdymuCWG2oY0/foSQlXp1
JP2xTvrndmZb7daOhxqx8ddzcNwjgNns2YO9nCImAZhZaUiYYGeO643c32M4laUTY/QvSgNoAhMr
mXddzaqlAdp4a9TyhyUAWd3cgprazO/unorZAkjWaGlfhRKmsuSSkEin6RAeaX2I5Fb2QK1ugHEK
mW7d5wKWdIzWjagcvghbCmMkUKN8uqABqKfwhQ0ZUd2G31/OW710ty0sTLrhzHB9eMrf0mzrL0uV
pPWHwckKPmKY1K9HSEGXKgtwWZF6UUDt0Jb0MN5fSu5kKxPNWTiAJQt0zS+Z4vrBHXqlAUlOmXxa
y31aTBsOnM90hUa/i4imiwiHmdu4pOQTKY+wQEZzxAH3YLu4BvmZ+4mYNz98+Ddub9+z8ILe7dRM
FBnTb0xz3DagjZn9/yJ5xFvGgT+B8/XIu4anRfCwL9pDu59rMOIN7vPOHu2XkLWHHagl/uN6Sap6
6PuEPrFMUNmvUn/i+wd7djRDDAsAhRk2AB2FI8A692j0hisrLGG4GGocQIUC67jtSTaJodB6slz8
Z8wk1D8UwY=X02k0
```
 Confluence for B836-9R3J-BUA5-XMAI, Entitlement Number: 
```
AAABnw0ODAoPeJx1UV1vqjAYvu+vIDmXC9rCRDFpcrCyiQdwEVmWc1fZ6+iGxbTFTX/9EFlOcrIlv
en7tO/z9StrpJXWRwv7Fh5NHX9661v5hlkOdkaIKeBG1HLODdDLxCbExj4Kj7xqOoTueKUBzUEXS
hy6SS4rsRcGnq1KFCA1WNuTVRpz0NPh8FyKCgaiRiv1wqXQ1yW1hFgsowAVtdwNeGHEEahRDSBWS
9Pew4SLil7QqgFZwG9uKq614HJQ1HvUEy24LmnC3tnd3SgJSJwO/c2qDu/1zVO8+BsE+pynEJRrv
rh5cAonw8vo/GeX3rLn1ywgZMbeXii9asgMVwZUb68bxVeSzekAKd8DZaskCdcsCmLUqpMGJG+Vh
R8HoU59YBPfxuP2oP5vNKdxNM/C1I7J2HM8zyMTn3guykAdQbXwbOJ6tr92l/YsD0b2UxJEV/Z2I
2cgL5q6YN7g9AhKX9IjHsZjPHFd8sXzvYiHRhUl1/B/m316X+sclDXbf3V2bJ2EtNlvQa12uW5fU
pug1gj9xkzfWRfST5V9At2DzvUwLAIUfah2PZn0zikr/zwqCxGLseJVRrcCFBZy1ThSY1wlvnj0H
eDSe8z5ar1tX02k0
```

- use below command to generate the key for plugin.
  ```
  docker exec -it <containerID> /bin/bash

  java -jar /opt/atlassian/confluence/bin/atlassian-agent.jar -d -m confluence@atlassian.com -o oneLiJIA -s B836-9R3J-BUA5-XMAI -p <appkey>
  ```
App key: com.miniorange.oauth.confluence-oauth
```
AAABsw0ODAoPeJyNUtFumzAUffdXIO2ZxEAISSRLpYQmbIF0pWTt3hxyU9yBobahY18/AokqVZsUy
X65vj7nnnPul5gqLSobDc8001hY9mJiasmjp5nYtJEngCpW8iVVQE4V3TB0PEMblgKX8NhWENECi
LcNQ//BC9wN8hua1/0ncqS5BLQEmQpW9ZWE56xgCg5aPiBo+1bLlKrkYjz+k7EcRqxEaVmMCsZZK
Sh/gVFJa5WN0pIf8xp4CvpQAK5AVIJJIErUgLbihXImB+qSw4Z9DdwrsTp91OsBByyv5Iqmyg8py
8lH9w1VOZWSUd5BFOisYU1lRkLv3bu73YeVHc6NAGNvbh1WD0/Pq6SdTCN152bf1/b9mzTdZjxOr
OfyINb89fVp+7b7UbmEoI6q4+e0o/F/V0y0Z89ncx073blSSayoOMkYvI9BNCCCJbn9Zq/1ZWCE+
uYn3ulhspqjX9DuQMiTXcYUYwfPLMtAUV3sQWyPiezeiG5csv73UPe1SDMq4fOCXDdsZzFrzvGdz
bxMZKK43n8sTt8S+xHprr4xnKk5tRxnYpqOfQmrX8T/ZfUXoYb/MjAsAhQQ9G5zzodtL7MQsvvuN
a4WhmoPWwIUJ9/LTkkWqQKgLzvMtjglVwHHaTY=X02ks
```

## update Confluence License code (optional)
- update the license code in /var/atlassian/application-data/confluence/confluence.cfg.xml
  - sed -i 's/BESS-JWMK-Z9AG-51RE/LIJA-FMLY-WIKI-8888/g' /var/atlassian/application-data/confluence/confluence.cfg.xml
  - <property name="confluence.setup.server.id">SYAU-LIJA-FMLY-9658</property>
- update in database table
  - update BANDANA set bandanavalue = '<string>LIJA-FMLY-WIKI-8888</string>' where bandanakey = 'confluence.server.id';