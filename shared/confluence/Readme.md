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
    - ATL_JDBC_URL=jdbc:postgresql://postgresql:5432/svchubwwhome
    - ATL_JDBC_USER=dbservice
    - ATL_JDBC_PASSWORD=
  ```
- create database and grant permission in PostgreSQL
  ```SQL
  >> psql -U dbservice
  DROP DATABASE svchubwwhome;
  CREATE USER dbservice WITH PASSWORD 'cc9c3130e3820945fe';
  CREATE DATABASE svchubwwhome;
  GRANT ALL PRIVILEGES ON DATABASE svchubwwhome TO dbservice;
  ```

## Activation
- use below command to generate the key for Confluence
  ```
  docker exec -it <containerID> /bin/bash

java -jar /opt/atlassian/confluence/bin/atlassian-agent.jar -d -m home@onelijia.com -p conf -o oneLiJIA -s BV3O-3TEO-CUCG-185G

  SYAU-LIJA-FMLY-9688
  ```
  - p > product,  conf = confluence
  - o > server address,  in my case, it's Lifamy.com
  - m > mailbox
  - n > account name
  - s > server ID

License Key: BV3O-3TEO-CUCG-185G  Entitlement Number: SEN-L1788869709841

```
AAABnA0ODAoPeJxtUV1vozAQfPevQLpnUgNN4kSy1BRIjxOEXIFI7ZvDbYp7YDjbkI9ff4RQnXSt5
JedXe/MznxLWzASaAxMDMteWtMlXhhZ6ho2tmfIlcA0r4XHNNArYuKFiQnyO1a2Q4ceWKkAeaByy
ZsByUTJK67hl1HyHIQCY382Cq0btby7uxS8hAmvUSzfmODqtqQWEPIfwQrltThMWK55B1TLFpBbC
93XfsR4SYu6god+tuTvnE3yukIjw3emChq5R3e9fnd869Rl3SWpROJsX71L9Lh9SV6PZFU8by84J
zzYxerEdvcvx7c/U+mnU3vd/KT0Rp5oJjXI8a4BCm8k6bmBDauAunEU+c9usApRL0toEEzk4J8aL
s+jU6S3ad4/NP4NPBoGXuJvzNCaE0JmizlekHsLJSA7kH37cefEppP6selm7pNpkenTjb3fyFwQV
02DI7/hvAOprrZZM4znmDiO9cHztYhtK/OCKfg/xtG9j3U2Str9vxwHtkHCpq32IONDpvpJavaq/
Q394pgxrMGkT1n9BZZby00wLAIUfMwqOnZeHSm46CVuIvMNmGw/KOoCFFe9DxOb67kgnCsbLtAsY
Nr8wUpnX02jr
```

Confluence License Key: B55G-1OYC-GUO0-GR7N, Entitlement Number: EN-L1788848802603
```
AAABmw0ODAoPeJxtkV+PojAUxd/7KUj2GSk4KmPSZJ3CqLv82YiY9bGw16EKhbRFVz/9IjLZZGaSv
vTe9p5zf+fbtgUjgcbAroGnc2c6f3KMdEsNBztTRCUwzWvhMQ3kXjHxs4ld5J9Z2fYdcmClAuSBy
iVv+koqSl5xDX+MkucgFBjZ1Si0btTcsm4FL2HEaxTLNya4egypBQT8x3qB8locRizX/AxEyxYQr
YXu7n7IeEmKuoLv3duSHzkb5XWFBoUVUwUJ6YW+0pN9yy4HaH++3n5HkdfQ4woH8WliJYti83yxQ
itdnVfHXZkF4/0pUS97vsOseCPkIZ5oJjXIYa++FDxEttcGIlYBoXEY+hu6XgSosyU0CCZy8P82X
F4HUm6HadYdNPxdeyRYe4kfmYE9c133yXU7mniMEpBnkF37ZTJZmna8p+YyjbG53Myih3o3kVEQd
089kRNcdyDVHZs9xXiG3fHYftf52sSvVuYFU/AxxoHe+zgHJW32P8derbcQtVUGMj6kqntJTBt1i
5AvlhnC6iF9yuofKk7K+zAtAhUAlI2tKvEl3OXCIpttQL+BX5u89ZoCFDi11OD0ollSXk9+ttFGZ
HAN6tLcX02jr
```

- use below command to generate the key for plugin.
```
  docker exec -it <containerID> /bin/bash

java -jar /opt/atlassian/confluence/bin/atlassian-agent.jar -d -m confluence@atlassian.com -o oneLiJIA -s B55G-1OYC-GUO0-GR7N -p <appkey>
```

App key: com.atlassian.confluence.plugins.confluence-questions
```
AAABrA0ODAoPeJylkkFvozAQhe/+FUh7JjXQBhrJUlmHJlQkNEtI9+qwQ7AKxmub7Ka/fklC1KpqL
13JvjzL38y8ed/WHVgZSAsHluNO3PHEwVa+ppaL3TEq2mbETM205kyMilaUdQeigJGsux0X+o1k/
+5AG972YmaYMqBIyWoNiCpgR33KDJAj1ca3Ng5QwgsQGtYHCUvWAKHpYhH9oHGYoGjP6u70aWBMQ
ReKy5OSi5o33MAvqz4TrO3BqoyRenJ19VLxGka8RanaMcH1GdIKSPhDHCLaCsMKEy0Yr8lr73dvZ
2zQwJ0zXZEF/UPvpw8NVnlsYql1uFytSowfg6f5Kt3ehtUqNps8Cf25YP51/LL3iueilDOcPf3cE
YL6UsKAYH2Z6K/k6jD4EPQm+P35osc9hVEQR5uN6uCLlBNAKq7hfyi9o3w/EDJQe1DxlHzfeKntr
aPUpjmd2U5wM0PPcNiA0seVOGOMfRx4noOWXbMFlZa57t+I7VyS8bFdj50qKqbhfZyGpV34Lsq67
Wtozr1FS9JfO3H8IAh87PkY4+tLKE4h/CwT/wDRRxoTMCwCFGvH1V/cfWyo8LJfa1a4TbWT/QxOA
hR8G/1SKL1gm1yZWoDUPbcPkikNRA==X02kk
```

App key: com.resolution.atlasplugins.samlsso.Confluence
```
AAABuA0ODAoPeJyVUl1vmzAUffevQNpjBRhogUSytJRQloyErkCkPTr0JnhzDLJN2uzXz/lapWl7i
GS/+Pqee84951M1gFVCb+HY8vyxH46DyKqrxPKxH6JEAtWsE1OqgRxfbDyycYxy1oBQUB16WNIdk
KRYLNKXZDbJUbqnfDg1kQ3lCtAUVCNZf3qpBWc7puHV4mcEa32wWq17NXbdXy3j4LAONd3OkaA6P
hybHKo5VT0ftkwoR9EdV6pzkk5s+ACiAceQowkIDZJoOQAq5JYKps4cOgE5m88mt4Ke8HrJFJxBT
UnTRqcLyjhp/vz7fMJRjArHDEAXVV+oaskieUue0u1Qzt+qeumu9m55mIeTH81rKJ8X1fdJ++0hv
2tafP+Yzb5O3af3u/sGy2VW4iDbEoLMKENCUDMmfe+ZPFxciI0FkTm3SjL02f4ipwS5BzmbksdVU
NhBlRZ2UieZ7cUPGfoJhxVIdVyfF2Ic4TgIPLQcdmuQxaZWpkZs7xqCf3N7HmTTUgV/J+dGzqWm8
mjsOUqX9V7J+agc1h/hOgtLl8RcO/eiOI4jHIyikT+62ncK6//c+w2l7g5dMC0CFBpnkgjxoPHIC
7a5FNEYlmdXD/eKAhUAkzlBAHjdRy9+Nmk0eZ4GiFay+uk=X02l5
```

App key: com.k15t.scroll.scroll-viewport
```
AAABrA0ODAoPeJyFUl2P2jAQfPeviNTHKiEfHEmQLJWaHKVNSK8kvDthIS7GiWwnHPfrL0BQpdNVS
LYs7WpnZmf8JWvBWENj2IHhuFPXnzqBkWfEcG13gogEqlkt5lQDvlRMOzTtAMWsBKEgOzewokfAJ
E2S6A9ZzmIUdZS31yG8o1wBmoMqJWuulVxwdmQatga/IRjF2ai0btR0NHqrGAeL1SiVeyqYuoHUA
mL2czlDpBaaljpKKOO4rMWOtyBK+EY1p0oxKqyyPqIB9wdVFU7IiTwTN5R5KFXhOf6vbXd49U7hP
vK6dTyaVS9+vi9I8vZMNovN1zAS28xdMOfveOy/YIx6KqFB0J4mem2YPA8+BL0Jfn9Qz2gdnCdt9
SvWnA+P2TE4NbXUVq+XdYC1bAGtQXYgl3P8feOlppdFqUlysjCd4GmBDnDegFSXhZ2Jbft24HkOW
rXHAmS6y1Xfw6Zz9/1zMb9bWVZUwcewHolcayo1yCGuwcC7GvfheE9HCYgLwm3PtvgX+K0SrXB/z
djxgyDw7bEX+OPJPdDrB/pvno/Yr8SNZOrm8jt3ufQ8MCwCFFs5bnNci8SUOcjzGURT9hNpH70JA
hRcIQyEJdeouTPLGy2lx9IYs3uLIQ==X02kk
```


App key: com.stiltsoft.confluence.plugin.tablefilter.tablefilter
```
AAABuQ0ODAoPeJydUl1vmzAUffevQNpjBDVkCSwS0lJDWjIIXQPZx5vDbopXY5htoqW/fk5IVK3aX
iLZluUrn3vuOedd0YO1hs7CgeV6M8+fTbBVFsTysDdFRALVrBUR1RAeX2z8wcYBSlkFQkFx6GBFG
whJnmXxI0nmKYr3lPenT+GOcgWoahtHaca1anfaqVqx4z2ICpyO909MOJpuOexMHeRfdxDm7CRTE
GrZA4pAVZJ1J+RScNYwDT8sPjCxtger1rpTs5ubl5pxcFiLcvlEBVMDmVZAypbJHJFWaFrpOKOMh
690PlLNqVKMCsOxQWfce6rqMCOYLBbfVbwpSezTsky/LPRoepssE50U7GFel/Nnxaej0ef6ZRR9+
tqI+2j56+f+m2BuFoTItDLDCGraxL87Jg9nPQMjpm/W1RoZHEpOQg0arUHuQSZReLsZ5/a4iHObl
OTOdoPJHXqGwwakOorhTjH2cTAeu2jVN1uQ+a5Uphba7sXbfxN96GVVUwVvA3HtAGtN5ZH9EJWz6
BeWHlr321fThwnjVWi2nbp+EAQ+fu9jL5hcTD2F8b+eXkvSALP9kMI/2iAc1zAsAhQnyC2+MUKFv
CTwwagDtXC8oYxZVAIUMXpTfHP1JxDpxoSpMEiU2YiAAEI=X02l5
```

## update Confluence License code (optional)
- update the license code in /var/atlassian/application-data/confluence/confluence.cfg.xml
  - sed -i 's/BESS-JWMK-Z9AG-51RE/LIJA-FMLY-WIKI-8888/g' /var/atlassian/application-data/confluence/confluence.cfg.xml
  - <property name="confluence.setup.server.id">SYAU-LIJA-FMLY-9658</property>
- update in database table
  - update BANDANA set bandanavalue = '<string>LIJA-FMLY-WIKI-8888</string>' where bandanakey = 'confluence.server.id';