# 24nonStop модуль для NoDeny 49/50

Модуль для биллинговой системы NoDeny реализует протокол взаимодействия с [платежной системой 24nonStop](http://www.24nonstop.com.ua).

## Установка

- Скопировать вложенный скрипт в директорию /usr/local/www/apache22/cgi-bin/
- Изменить настройки скрипта:
  - SECRET - сгенерированный случайно секретный ключ
  - SERVICEID - код сервиса
  - LOGIN - логин для доступа к базе данных bill
  - PASSWORD - пароль для доступа к базе данных bill

- Создать файл /usr/local/nodeny/module/nonstop24.log и установить права записи для веб-сервера

В качестве платежного кода используется код, который выводится у каждого абонента в его статистике внизу ("Ваш персональный платежный код: …")

## Maintainers and Authors

Yuriy Kolodovskyy (https://github.com/kolodovskyy)

## License

MIT License. Copyright 2013 [Yuriy Kolodovskyy](http://twitter.com/kolodovskyy)
