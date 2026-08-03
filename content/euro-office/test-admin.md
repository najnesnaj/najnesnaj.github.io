podman exec 5b20c2d166c0 sudo supervisorctl start example
example: started
http://localhost:8081/example/

podman exec 5b20c2d166c0 sudo supervisorctl start adminpanel
adminpanel: started
http://localhost:8081/admin/


Euro-Office Admin Panel

Initial Setup

Enter the bootstrap token from server logs and create your admin password.


in container : 
root@5b20c2d166c0:/var/log/euro-office/documentserver/adminpanel# more out.log 
[2026-08-03T10:12:57.151] [WARN] [localhost] [docId] [userId] nodeJS - AdminPanel server starting...
[2026-08-03T10:12:57.153] [WARN] [localhost] [docId] [userId] nodeJS - AdminPanel server listening on port 9000
[2026-08-03T10:12:57.154] [WARN] [localhost] [docId] [userId] nodeJS - AdminPanel SETUP REQUIRED | Bootstrap code: RU8AAD18FAHG | Expires: 2026-08-03T11:00:00.000Z | Open: http://host/admin
[2026-08-03T10:48:01.812] [WARN] [localhost] [docId] [userId] nodeJS - Bootstrap code verification failed: invalid format
[2026-08-03T10:48:01.812] [WARN] [localhost] [docId] [userId] nodeJS - Invalid or expired bootstrap token attempt
[2026-08-03T12:34:27.535] [WARN] [localhost] [docId] [userId] nodeJS - Bootstrap code verification failed: invalid format
[2026-08-03T12:34:27.535] [WARN] [localhost] [docId] [userId] nodeJS - Invalid or expired bootstrap token attempt
[2026-08-03T12:35:22.242] [WARN] [localhost] [docId] [userId] nodeJS - Bootstrap code generated on demand | Code: 29JOK5P2DQ1L | Expires: 2026-08-03T13:00:00.000Z
[2026-08-03T12:37:07.530] [WARN] [localhost] [docId] [userId] nodeJS - Bootstrap code verification failed: invalid format
[2026-08-03T12:37:07.530] [WARN] [localhost] [docId] [userId] nodeJS - Invalid or expired bootstrap token attempt
[2026-08-03T12:39:14.617] [WARN] [localhost] [docId] [userId] nodeJS - AdminPanel server starting...
[2026-08-03T12:39:14.619] [WARN] [localhost] [docId] [userId] nodeJS - AdminPanel server listening on port 9000
[2026-08-03T12:39:14.620] [WARN] [localhost] [docId] [userId] nodeJS - AdminPanel SETUP REQUIRED | Bootstrap code: CI3DELLAM46Y | Expires: 2026-08-03T13:00:00.000Z | Open: http://host/admin
root@5b20c2d166c0:/var/log/euro-office/documentserver/adminpanel# 

