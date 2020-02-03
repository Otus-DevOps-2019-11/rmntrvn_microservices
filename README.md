# rmntrvn_microservices
rmntrvn microservices repository

## Домашняя работа 13 "Docker контейнеры. Docker под капотом"

1. Загружен образ *rmntrvn/ubuntu-tmp-file* из созданного образа и загружен в *docker-hub*.
 - https://hub.docker.com/repository/docker/rmntrvn/ubuntu-tmp-file
 - [docker-1.log](docker-monolith/docker-1.log)
2. (*) Выполнено задание сранения образа и контейнера. Результат описан в файле [docker-1.log](docker-monolith/docker-1.log)
Кратко: Docker image - шаблон для создания контейнеров, содержит информацию о слоях файловых системы и зависимость от родительских образов. Docker conteiner - экземпляр на основе образа docker, содержит настройки сети контейнера, информацию об образе и состояние контейнера.
3. Docker-machine: создан хост для docker с использованием docker-machine следующей командой:
```
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20200129 \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \
docker-host
```
Проверяем созданную машину в GCP.
```
$ docker-machine ls
NAME          ACTIVE   DRIVER   STATE     URL                         SWARM   DOCKER     ERRORS
docker-host   -        google   Running   tcp://104.155.32.211:2376           v19.03.5
```
Создаём окружение для дальнейшей работы с Docker:
```
eval $(docker-machine env docker-host
```
4. Следующая команда возвращает htop процессов внутри контейнера:
```
docker run --rm -ti tehbilly/htop
```
Следующая команда возвращает htop процессов хост-машины:
```
docker run --rm --pid host -ti tehbilly/htop
```
5. Создадим следующие файлы для сборки образа docker:
 - [Dockerfile](docker-monolith/Dockerfile)
 - [db_config](docker-monolith/db_config)
 - [start.sh](docker-monolith/start.sh)
 - [mongod.conf](docker-monolith/mongod.conf)
Все файлы должны находится в директории docker-monolith.
Выполним сборку образа (необходимо находиться в директории docker-monolith):
```
docker build -t reddit:latest .
```
Просмотрим все образы:
```
$ docker images -a
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
reddit              latest              d17b5c0b1a53        2 minutes ago       692MB
<none>              <none>              bb568e7b65ef        2 minutes ago       692MB
<none>              <none>              1e4d479ee790        2 minutes ago       692MB
<none>              <none>              e5514ec6f401        2 minutes ago       646MB
<none>              <none>              1deed02557c3        2 minutes ago       646MB
<none>              <none>              c58b6839fe76        2 minutes ago       646MB
<none>              <none>              fa054b5046cc        2 minutes ago       646MB
<none>              <none>              46d45ffb5a7f        2 minutes ago       646MB
<none>              <none>              22431e675369        2 minutes ago       643MB
<none>              <none>              4d4d978bea65        3 minutes ago       149MB
ubuntu              16.04               96da9143fb18        2 weeks ago         124MB
tehbilly/htop       latest              4acd2b4de755        22 months ago       6.91MB
```
Выполним запуск контейнера командой:
```
docker run --name reddit -d --network=host reddit:latest
```
После чего проверим результат:
```
docker-machine ls
NAME          ACTIVE   DRIVER   STATE     URL                         SWARM   DOCKER     ERRORS
docker-host   *        google   Running   tcp://104.155.32.211:2376           v19.03.5
```
Проверим работу приложения по URL `104.155.32.211:9292`. При проверке возникает ошибка, связанная с настройкой сетевого экрана GCP. Установим правило:
```
gcloud compute firewall-rules create reddit-app \
--allow tcp:9292 \
--target-tags=docker-machine \
--description="Allow PUMA connections" \
--direction=INGRESS
```
После чего повторяем доступ к `104.155.32.211:9292`. Приложение работает.
6. Установим тег для созданного образа и загрузим его в docker-hub.
```
docker tag reddit:latest rmntrvn/otus-reddit:1.0
docker push rmntrvn/otus-reddit:1.0
```
7. Скачаем и запустим контейнер с загруженного ранее образа из docker-hub на локальную машину (предварительно нужно открыть другой терминал).
```
docker run --name reddit -d -p 9292:9292 rmntrvn/otus-reddit:1.0
```
Проверяем работу контейнера на локальной машине:
```
http://127.0.0.1:9292/
```
8. Просмотрим логи работы с контейнером:
```
docker logs reddit -f
```
Проверяем процессы внутри контейнера:
```
$ docker exec -it reddit bash
root@77613b79ba8c:/# ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0  18028  2712 ?        Ss   12:41   0:00 /bin/bash /start.sh
root         8  1.5  0.5 391400 37768 ?        Sl   12:41   0:16 /usr/bin/mongod --fork --logpath /var/log/mongod.log --config /etc/mongodb.conf
root        17  0.2  0.4 718644 31644 ?        Sl   12:42   0:02 puma 3.10.0 (tcp://0.0.0.0:9292) [reddit]
root        35  1.2  0.0  18240  3244 pts/0    Ss   12:58   0:00 bash
root        50  0.0  0.0  34420  2864 pts/0    R+   12:58   0:00 ps aux
root@77613b79ba8c:/# killall5 1
root@77613b79ba8c:/# %
```
Предыдущая команда завершила процесс контейнера. Запустим снова:
```
docker start reddit
```
Остановим и удалим контейнер:
```
docker stop reddit && docker rm reddit
```
Снова запустим контейнер следующей командой.
```
docker run --name reddit --rm -it rmntrvn/otus-reddit:1.0 bash
root@8c8528989635:/# ps aux
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  1.1  0.0  18232  3248 pts/0    Ss   13:08   0:00 bash
root        15  0.0  0.0  34420  2884 pts/0    R+   13:09   0:00 ps aux
```
После выхода из контейнера все данные файловой системы контейнера будут очищены.
Снова запустим контейнер в фоновом режиме.
```
docker run --name reddit -d -p 9292:9292 rmntrvn/otus-reddit:1.0
```
Выполним следующие команды:
```
docker exec -it reddit bash
root@50953a0c7ca5:/# mkdir /test1234
root@50953a0c7ca5:/# touch /test1234/testfile
root@50953a0c7ca5:/# rmdir /opt
root@50953a0c7ca5:/# exit
```
И сравним с образом на основе, которого был создан контейнер.
```
A /test1234
A /test1234/testfile
C /var
C /var/lib
C /var/lib/mongodb
A /var/lib/mongodb/mongod.lock
A /var/lib/mongodb/_tmp
A /var/lib/mongodb/journal
A /var/lib/mongodb/journal/prealloc.1
A /var/lib/mongodb/journal/prealloc.2
A /var/lib/mongodb/journal/j._0
A /var/lib/mongodb/journal/lsn
A /var/lib/mongodb/local.0
A /var/lib/mongodb/local.ns
C /var/log
A /var/log/mongod.log
C /root
A /root/.bash_history
C /tmp
A /tmp/mongodb-27017.sock
D /opt
```
Изменения были залогированы.
Снова создадим контейнер и проверим наличие директории /opt
```
$ docker run --name reddit --rm -it rmntrvn/otus-reddit:1.0 bash
root@5bb94283f2a5:/# ls /
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  reddit  root  run  sbin  srv  start.sh  sys  tmp  usr  var
```

9. (*) На основе предыдущих заданий создан прототип инфраструктуры в директории `/docker-monolith/infra/`:
 - Создан [docker.json](docker-monolith/infra/packer/docker.json) для упаковки образа с установленным Docker, который собирается из плейбука [packer_docker.yml](docker-monolith/infra/ansible/playbook/packer_docker.yml),
 - Создан код инстраструктуры terraform в директории `docker-monolith/infra/terraform/`,
 - Созданы плейбуки для установки приложения через Ansible в директории `/docker-monolith/infra/ansible/`.

 Для проверки выполнить:
 - В директории `docker-monolith/infra/packer` выполнить команду
 ```
 packer build -var-file=./variables.json docker.json
 ```

 - В директории `docker-monolith/infra/terraform` поднять инфраструктуру командой:
 ```
 terraform init && terraform apply -auto-approve
 ```
 После старта будет получен внешний IP адрес *docker-machine*.

 - Запустить плейбук в директории `docker-monolith/infra/ansible` для загрузки образа и старта контейнера с приложением:
 ```
 ansible-playbook playbook/site.yml
 ```

 После отработки плейбука проверить доступность приложения по IP внешнему IP адресу (80 порт docker-machine будет проброшен на 9292 порт контейнера). Настройка проброса порта устанавливается в плейбуке [docker.yml](docker-monolith/infra/ansible/playbook/docker.yml)
