# rmntrvn_microservices
rmntrvn microservices repository

## Домашняя работа 16 "Устройство Gitlab CI. Построение процесса непрерывной интеграции"

1. Создан Docker host:
Экспортирован проект.
```
export GOOGLE_PROJECT=docker-267008
```
Cоздана ВМ с рекомендуемыми параметрами (1vCPU, 3.75GB vRAM, 100GB HDD, Ubuntu 16.04):
```
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20200129 \
--google-machine-type n1-standard-1 \
--google-disk-size 75 \
--google-zone europe-west1-b \
gitlab-ci
```
Создано окружение для дальнейшей работы с Docker:
```
eval $(docker-machine env gitlab-ci)
```
Открывает трафик HTTP/HTTPS для виртуальной машины, подключаемся к docker хосту `docker-machine ssh gitlab-ci` и выполняем команду.
```
mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs
```
Переходим в директорию `/src/gitlab/` и создаем *docker-compose.yml* файл.
```
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'http://104.155.19.233'
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'
```
Где `104.155.19.233` - IP виртуальной машины.
После этого выполняем `docker-compose up -d` и дожидаемся загрузки образа и старта контейнера, и проверяем Gitlab по IP 104.155.19.233. Вводим пароль для пользователя root и выполняем авторизацию. Далее отключаем регистрацию новых пользователей.
2. Создадим группу проектов *homework* и проект *example*.
Добавляем удаленный репозиторий.
```
git remote add gitlab http://104.155.19.233/homework/example.git
git push gitlab gitlab-ci-1
```
3. Создадим файл `.gitlab-ci.yml` в корне репозитория.
```
stages:
  - build
  - test
  - deploy

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  script:
    - echo 'Testing 1'

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_job:
  stage: deploy
  script:
    - echo 'Deploy'
```
Выполним пуш файла в репозиторий.
```
git add .gitlab-ci.yml
git commit -m 'add pipeline definition'
git push gitlab gitlab-ci-1
```
3. Далее зарегистрируем runner: перейдём в Setting / CI/CD / Runner Setting / Expand / скопируем полученный токен.
4. Далее выполним команду.
```
docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```
5. Далее зарегистрируем runner.
```
docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false
```
```
Runtime platform                                    arch=amd64 os=linux pid=31 revision=003fe500 version=12.7.1
Running in system-mode.

Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
http://104.155.19.233/
Please enter the gitlab-ci token for this runner:
MiwZmZHV1PsUB9tdERn9
Please enter the gitlab-ci description for this runner:
[e09c6ddeb3f1]: my-runner
Please enter the gitlab-ci tags for this runner (comma separated):
linux,xenial,ubuntu,docker
Registering runner... succeeded                     runner=MiwZmZHV
Please enter the executor: docker+machine, docker-ssh+machine, kubernetes, docker, docker-ssh, ssh, virtualbox, custom, parallels, shell:
docker
Please enter the default Docker image (e.g. ruby:2.6):
alpine:latest
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
```
После запуска pipeline должен запуститься. Добавим исходный код reddit в репозиторий.
```
git clone https://github.com/express42/reddit.git && rm -rf ./reddit/.git
git add reddit/
git commit -m “Add reddit app”
git push gitlab gitlab-ci-1
```
6. Изменим описание пайплайна `.gitlab-ci.yml`. После изменений пайплайн будет выглядеть следующим образом.
```
images: ruby:2.4.2

stages:
  - build
  - test
  - deploy

variables:
  DATABASE_URL: 'mongodb://mongo/user_posts'
  before_script:
  - cd reddit
  - bundle install

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  services:
    - mongo:latest
  script:
    - ruby simpletest.rb

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_job:
  stage: deploy
  script:
    - echo 'Deploy'
```
В описании пайплайна добавлен вызов теста скрипта simpletest.rb, который необходимо создать в директории reddit.
```
require_relative './app'
require 'test/unit'
require 'rack/test'

set :environment, :test

class MyAppTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_get_request
    get '/'
    assert last_response.ok?
  end
end
```
Добавим `gem 'rack-test'` в файл Gemfile в директории reddit.
7. Переименуем deploy stage в review, deploy_job заменим на deploy_dev_job и укажем окружение dev.
```yaml
deploy_dev_job:
 stage: review
 script:
 - echo 'Deploy'
 environment:
 name: dev
 url: http://dev.example.com
```
8. Для staging и production укажем ручной запуск jobs, прописал `when: manual`. Также для stage и production укажем версионирование `only: - /^\d+\.\d+\.\d+/`. Job будет запущен только тогда, когда будет указана версия при пуше. Например:
```
git commit -a -m ‘#4 add logout button to profile page’
git tag 2.4.10
git push gitlab gitlab-ci-1 --tags
```
9. Создадим динамические окружения.
```
branch review:
 stage: review
 script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
 environment:
 name: branch/$CI_COMMIT_REF_NAME
 url: http://$CI_ENVIRONMENT_SLUG.example.com
 only:
 - branches
 except:
 - master
```
10. (*)


---

## Домашняя работа 15 "Сетевое взаимодействие Docker контейнеров. Docker Compose. Тестирование образов"

1. Создан Docker host:
Экспортирован проект.
```
export GOOGLE_PROJECT=docker-267008
```
```
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20200129 \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \
docker-host
```
Создано окружение для дальнейшей работы с Docker:
```
eval $(docker-machine env docker-host)
```

2. Запустим контейнер с сетью *none*.
```
docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig
Status: Downloaded newer image for joffotron/docker-net-tools:latest
lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```
Видим, что в контейнере из сетевых интерфейсов только loopback интерфейс. Данный тип сети используется для тестирования и запуска одноразовых контейнеров.
Запустии контейнер в сетевом пространстве docker-хоста.
```
docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig
docker0   Link encap:Ethernet  HWaddr 02:42:9F:01:74:67
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

ens4      Link encap:Ethernet  HWaddr 42:01:0A:84:00:1B
          inet addr:10.132.0.27  Bcast:10.132.0.27  Mask:255.255.255.255
          inet6 addr: fe80::4001:aff:fe84:1b%32538/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1460  Metric:1
          RX packets:4726 errors:0 dropped:0 overruns:0 frame:0
          TX packets:3761 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:109018116 (103.9 MiB)  TX bytes:393229 (384.0 KiB)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1%32538/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```
Сравним с сетевыми интерфейсами docker-хоста.
```
$ docker-machine ssh docker-host ifconfig
docker0   Link encap:Ethernet  HWaddr 02:42:9f:01:74:67
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

ens4      Link encap:Ethernet  HWaddr 42:01:0a:84:00:1b
          inet addr:10.132.0.27  Bcast:10.132.0.27  Mask:255.255.255.255
          inet6 addr: fe80::4001:aff:fe84:1b/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1460  Metric:1
          RX packets:4764 errors:0 dropped:0 overruns:0 frame:0
          TX packets:3802 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:109026757 (109.0 MB)  TX bytes:401326 (401.3 KB)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```
Запустим несколько раз контейнер Nginx (запущен 3 раза).
```
docker run --network host -d nginx
```
В итоге был запущен только 1 контейнер.
Остановим все контейнеры.
```
docker kill $(docker ps -q)
```
Подключимся к серверу docker-host по ssh.
```
docker-machine ssh docker-host
```
Создадим символьную ссылку.
```
sudo ln -s /var/run/docker/netns /var/run/netns
```
Теперь можем проверить существующие net-namespaces.
```
sudo ip netns
```
Снова создадим контейнер с сетью none и проверить существующие net-namespaces.
```
docker-user@docker-host:~$ sudo ip netns
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
75756d5fe471
default
```
Создадим контейнер с сетью host и проверим существующие net-namespaces.
```
docker-user@docker-host:~$ sudo ip netns
default
```
Итог: сеть none - изолирована, сеть host наследуюется от хостовой машины.
Создадим контейнер с сетью bridge:
```
docker network create reddit --driver bridge
```
Запустим проект с использованием bridge сети. Сначала соберем образы.
```
docker build -t rmntrvn/post:1.0 ./post-py
docker build -t rmntrvn/comment:1.0 ./comment
docker build -t rmntrvn/ui:1.0 ./ui
```
Поднемем контейнеры.
```
docker run -d --network=reddit mongo:latest
docker run -d --network=reddit rmntrvn/post:1.0
docker run -d --network=reddit rmntrvn/comment:1.0
docker run -d --network=reddit -p 9292:9292 rmntrvn/ui:1.0
```
При проверке наблюдаем, что сервисы не могут определить друг друга. Необходимо назначить сетевые алиасы для контейнеров. Останавливаем старые копии контейнеров.
```
docker kill $(docker ps -q)
```
Запускаем новые с указанием алисов.
```
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post rmntrvn/post:1.0
docker run -d --network=reddit --network-alias=comment rmntrvn/comment:1.0
docker run -d --network=reddit -p 9292:9292 rmntrvn/ui:1.0
```
После чего убеждаемся, что проект работает.
Теперь запустим проект в 2-х bridge-сетях. Остановим все контейнеры.
```
docker kill $(docker ps -q)
```
Создадим сети.
```
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24
```
Запустим контейнеры.
```
docker run -d --network=front_net -p 9292:9292 --name ui  rmntrvn/ui:1.0
docker run -d --network=back_net --name comment  rmntrvn/comment:1.0
docker run -d --network=back_net --name post  rmntrvn/post:1.0
docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest
```
Убеждаемся, что сервисы приложения не работают, т.к. при инициализации контейнера ему может быть присвоена только 1 сеть. Необходимо поместить контейнеры post и comment в обе сети.
```
docker network connect front_net post
docker network connect front_net comment
```
После чего убеждаемся, что работа сервисов восстановлена.

3. Рассмотрим как выглядит сетевой стек.
Подключимся к docker-host по ssh.
```
docker-machine ssh docker-host
```
Установим утилиту для работы с мостами.
```
sudo apt-get update && sudo apt-get install bridge-utils
```
Выполним следующую команду.
```
docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
fd2b748bf0f4        back_net            bridge              local
da120c291e3a        bridge              bridge              local
a3d1e2b46dcf        front_net           bridge              local
40c9737df49b        host                host                local
1e518a7f99a2        none                null                local
2a0cdd4d6daf        reddit              bridge              local
```
Выполним следующую команду.
```
ifconfig | grep br
br-2a0cdd4d6daf Link encap:Ethernet  HWaddr 02:42:ad:5d:c5:2e
br-a3d1e2b46dcf Link encap:Ethernet  HWaddr 02:42:ff:ca:96:f4
br-fd2b748bf0f4 Link encap:Ethernet  HWaddr 02:42:e3:3f:47:52
```
Просмотрим информацию о любом из интерфейсов br.
```
docker-user@docker-host:~$ brctl show br-fd2b748bf0f4
bridge name	bridge id		STP enabled	interfaces
br-fd2b748bf0f4		8000.0242e33f4752	no		veth81635ea
							vetha22cc60
							vethe7b0dd5
```
В данном примере отображены пары, которые участвуют в образовании моста.
Проверим правила iptables.
```
sudo iptables -nL -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination
DOCKER     all  --  0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL

Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
DOCKER     all  --  0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
MASQUERADE  all  --  10.0.1.0/24          0.0.0.0/0
MASQUERADE  all  --  10.0.2.0/24          0.0.0.0/0
MASQUERADE  all  --  172.18.0.0/16        0.0.0.0/0
MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0
MASQUERADE  tcp  --  10.0.1.2             10.0.1.2             tcp dpt:9292

Chain DOCKER (2 references)
target     prot opt source               destination
RETURN     all  --  0.0.0.0/0            0.0.0.0/0
RETURN     all  --  0.0.0.0/0            0.0.0.0/0
RETURN     all  --  0.0.0.0/0            0.0.0.0/0
RETURN     all  --  0.0.0.0/0            0.0.0.0/0
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9292 to:10.0.1.2:9292
```
Следующие правила отвечают за выдачу трафика контейнера из bridge-сетей.
```
MASQUERADE  all  --  10.0.2.0/24          0.0.0.0/0
MASQUERADE  all  --  172.18.0.0/16        0.0.0.0/0
MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0
```
Следующее правило отвечает за перенаправление трафика на адреса конкретных контенейров.
```
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9292 to:10.0.1.2:9292
```
Выполним команду `ps ax | grep docker-proxy` и убедимся, что запущен процеес docker-proxy, который прослушивает процесс на порту 9292.

4. Создадим файл [src/docker-compose.yml](./src/docker-compose.yml).
Остановим запущенные ранее контейнеры.
```
docker kill $(docker ps -q)
```
Выполним следующие команды.
```
export USERNAME=rmntrvn
docker-compose up -d
docker-compose ps
```
После запуска проверим доступность сервисов проекта.
Файл docker-compose.yml скорректирован. Теперь файл содержит, сети и параметры. Переменные хранятся в файле .env. Имя проекта возможно задать в переменной COMPOSE_PROJECT_NAME.

5. (*) Создан файл [docker-compose.override.yml](./src/docker-compose.override.yml), который позволяет:
 - Изменять код каждого из приложений, не выполняя сборку образа.
 - Запускать puma для руби приложений в дебаг режиме с двумя воркерами (флаги `--debug` и `-w 2`).

---

## Домашняя работа 14 "Docker образы. Микросервисы"

1. Создан Docker host:
Экспортирован проект.
```
export GOOGLE_PROJECT=docker-267008
```
```
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20200129 \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \
docker-host
```
Создано окружение для дальнейшей работы с Docker:
```
eval $(docker-machine env docker-host)
```

2. Установлен линтер [hadolint](https://github.com/hadolint/hadolint) для Dockerfile.

3. Скачан [архив](https://github.com/express42/reddit/archive/microservices.zip), распакован в корень репозитория и распакованный каталог *reddit-microservices* переименован в *src*.

4. В директории `src/post-py/`, отвечающей за написание постов, создадан [Dockerfile](./src/post-py/Dockerfile).
```
FROM python:3.6.0-alpine

WORKDIR /app
ADD . /app

RUN apk --no-cache --update add build-base && \
    pip install -r /app/requirements.txt && \
    apk del build-base

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
```
В директории `src/comment/`, отвечающей за написание комментариев, создадан [Dockerfile](./src/comment/Dockerfile).
```
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

CMD ["puma"]
```
В директории `src/ui/`, отвечающей за написание комментариев, создадан [Dockerfile](./src/ui/Dockerfile).
```
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```

5. Для работы приложения потребуется база данных MongoDB.
```
docker pull mongo:latest
```

6. Выполним сборку образов созданных ранее Dockerfile'ов.
```
docker build -t rmntrvn/post:1.0 ./post-py
docker build -t rmntrvn/comment:1.0 ./comment
docker build -t rmntrvn/ui:1.0 ./ui
```

7. Создадим сеть для контейнеров.
```
docker network create reddit
```
Проверим созданную сеть.
```
$ docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
5c0cac18d94b        bridge              bridge              local
20c02d25bdfd        host                host                local
275b837da4a4        none                null                local
a482cad2cb34        reddit              bridge              local
```

8. Запустим контейнеры.

```
docker run -d --network=reddit \
--network-alias=post_db --network-alias=comment_db mongo:latest

debbb4d3ef373949d5e0ad7b50a9ff3fbbc4c03f4c701d64bf5ad4899fa50456
```
```
docker run -d --network=reddit \
--network-alias=post rmntrvn/post:1.0

7840c3d9b7b38ca9e774026d25b5d7a5cfa9483f16235df41e951fce71884a1e
```
```
docker run -d --network=reddit \
--network-alias=comment rmntrvn/comment:1.0

bb10f27f218157ccc30f89496fc4255972ae8819f412a3e5a2530b91168a900f
```
```
docker run -d --network=reddit \
-p 9292:9292 rmntrvn/ui:1.0

19acdf721c6eeb7225ddf227de83a46a2911b97e5d5a55e463700b315d2a266a
```

9. Проверяем работу приложения по внешнему IP инстанса на порту 9292.

10. (*) Останавливаем все контейнеры.
```
docker kill $(docker ps -q)
```
После чего запускаем контейнеры с другими псевдонимами и переопределим переменные окружения не переписывая Dockerfile.
```
docker run -d --network=reddit \
--network-alias=post_db_new \
--network-alias=comment_db_new \
mongo:latest

docker run -d --network=reddit \
--network-alias=post_new \
--env POST_DATABASE_HOST=post_db_new \
rmntrvn/post:1.0

docker run -d --network=reddit \
--network-alias=comment_new \
--env COMMENT_DATABASE_HOST=commen_db_new \
rmntrvn/comment:1.0

docker run -d --network=reddit \
--env POST_SERVICE_HOST=post_new \
--env COMMENT_SERVICE_HOST=comment_new \
-p 9292:9292 rmntrvn/ui:1.0
```
После чего проверяем доступность приложение по внешнему IP инстанса на порту 9292.
*Теория по запуску контейнера с принудительным указанием окружения доступна [по ссылке](https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file)*.

12. Проверим размер Docker образов.
```
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
rmntrvn/ui          1.0                 9c18250f80dc        About an hour ago   784MB
rmntrvn/comment     1.0                 3585670cf868        About an hour ago   782MB
rmntrvn/post        1.0                 eeb286b71721        About an hour ago   110MB
mongo               latest              8e89dfef54ff        9 days ago          386MB
ruby                2.2                 6c8e6f9667b2        21 months ago       715MB
python              3.6.0-alpine        cb178ebbf0f2        2 years ago         88.6MB
```
13. Заменим Dockerfile UI на новый.
```
FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y ruby-full ruby-dev build-essential \
    && gem install bundler --no-ri --no-rdoc

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/
RUN bundle install
COPY . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```
Выполним его сборку.
```
docker build -t rmntrvn/ui:2.0 ./ui
```
Проверим размер образа.
```
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
rmntrvn/ui          2.0                 3b0f37768492        About a minute ago   459MB
rmntrvn/ui          1.0                 9c18250f80dc        About an hour ago    784MB
rmntrvn/comment     1.0                 3585670cf868        About an hour ago    782MB
rmntrvn/post        1.0                 eeb286b71721        About an hour ago    110MB
mongo               latest              8e89dfef54ff        9 days ago           386MB
ubuntu              16.04               96da9143fb18        3 weeks ago          124MB
ruby                2.2                 6c8e6f9667b2        21 months ago        715MB
python              3.6.0-alpine        cb178ebbf0f2        2 years ago          88.6MB
```
14. (*) Собраны образы на основе Alpine.
[post-py](./src/post-py/Dockerfile)
[comment](./src/comment/Dockerfile)
[ui](./src/comment/Dockerfile)
```
docker build -t rmntrvn/post:3.0 ./post-py
docker build -t rmntrvn/comment:3.0 ./comment
docker build -t rmntrvn/ui:3.0 ./ui
```
Проверим размер собранных образов.
```
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
rmntrvn/comment     3.0                 43a14c6e7e95        8 seconds ago       157MB
rmntrvn/post        3.0                 55b48fe1f062        41 seconds ago      106MB
rmntrvn/ui          3.0                 3d12b21c142b        2 minutes ago       159MB
rmntrvn/ui          2.0                 3b0f37768492        21 minutes ago      459MB
rmntrvn/ui          1.0                 9c18250f80dc        2 hours ago         784MB
rmntrvn/comment     1.0                 3585670cf868        2 hours ago         782MB
rmntrvn/post        1.0                 eeb286b71721        2 hours ago         110MB
mongo               latest              8e89dfef54ff        9 days ago          386MB
ubuntu              16.04               96da9143fb18        3 weeks ago         124MB
ruby                2.2                 6c8e6f9667b2        21 months ago       715MB
ruby                2.2-alpine          d212148e08f7        22 months ago       107MB
python              3.6.0-alpine        cb178ebbf0f2        2 years ago         88.6MB
```
Образы занимают значительно меньше места.
15. Выключи старые контейнеры.
```
docker kill $(docker ps -q)
```
Создадим новые копии контейнеров.
```
docker run -d --network=reddit \
--network-alias=post_db --network-alias=comment_db mongo:latest

docker run -d --network=reddit \
--network-alias=post rmntrvn/post:1.0

docker run -d --network=reddit \
--network-alias=comment rmntrvn/comment:1.0

docker run -d --network=reddit \
-p 9292:9292 rmntrvn/ui:2.0
```
После чего проверил приложение по внешнему IP на порту 9292. Созданного ранее поста нет. Чтобы такого не было необходимо создать *volume* для хранения нужной информации на хост машине.
Создадим его.
```
docker volume create reddit_db
```
Выключим старые контейнеры.
```
docker kill $(docker ps -q)
```
Создадим новые с монтированием тома для базы данных.
```
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest

docker run -d --network=reddit --network-alias=post rmntrvn/post:1.0

docker run -d --network=reddit --network-alias=comment rmntrvn/comment:1.0

docker run -d --network=reddit -p 9292:9292 rmntrvn/ui:2.0
```
После проверяем доступность приложения на внешнем IP инстанса на порту 9292, создадим новый пост и перезапустим контейнеры.
```
docker kill $(docker ps -q)
```
```
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest

docker run -d --network=reddit --network-alias=post rmntrvn/post:1.0

docker run -d --network=reddit --network-alias=comment rmntrvn/comment:1.0

docker run -d --network=reddit -p 9292:9292 rmntrvn/ui:2.0
```
После чего проверяем, что пост не удалился. База данных сохранилась на хостовой машине в директории `/var/lib/docker/volumes/reddit_db/_data`.

---

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
eval $(docker-machine env docker-host)
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
