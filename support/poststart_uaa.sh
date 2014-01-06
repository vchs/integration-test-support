uaac target http://localhost:8080/uaa
uaac token client get admin -s adminsecret
uaac client add service_controller -s service_controller_secret --scope "service_controller.user service_controller.admin" --authorized_grant_types "password authorization_code" --autoapprove "service_controller.user service_controller.admin" --authorities uaa.resource
uaac group add service_controller.user
uaac group add service_controller.admin
uaac user add admin@test.org -p admin --emails admin@test.org
uaac user add a@b.c -p abc --emails a@b.c
uaac user add p@q.r -p pqr --emails p@q.r
uaac member add service_controller.user a@b.c p@q.r
uaac member add service_controller.admin admin@test.org
