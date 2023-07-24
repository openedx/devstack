#!/usr/bin/env bash
echo 'Attempting to award a program certificate to the edX user'
echo 'Updating Discovery...'
echo 'Adding assets to the edX demo organization'
docker compose exec -T discovery bash -c 'mkdir /edx/app/discovery/discovery/provision-temp'
docker cp ./assets edx.devstack.discovery:/edx/app/discovery/discovery/provision-temp/assets
docker compose exec -T discovery bash -c 'source /edx/app/discovery/discovery_env && python /edx/app/discovery/discovery/manage.py add_logos_to_organization --partner=edX --logo=/edx/app/discovery/discovery/provision-temp/assets/demo-asset-logo.png --certificate_logo=/edx/app/discovery/discovery/provision-temp/assets/demo-asset-certificate-logo.png --banner_image=/edx/app/discovery/discovery/provision-temp/assets/demo-asset-banner-image.png'
docker compose exec -T discovery bash -c 'rm -rf /edx/app/discovery/discovery/provision-temp'

echo 'Updating credentials...'
echo 'setting catalog and lms base urls'
docker compose exec -T credentials bash -c 'source /edx/app/credentials/credentials_env && python /edx/app/credentials/credentials/manage.py create_or_update_site --site-domain example.com --site-name example.com --platform-name edX --tos-url https://www.edx.org/edx-terms-service --privacy-policy-url https://www.edx.org/edx-privacy-policy --homepage-url https://www.edx.org --company-name "edX Inc." --certificate-help-url https://edx.readthedocs.org/projects/edx-guide-for-students/en/latest/SFD_certificates.html#web-certificates --lms-url-root http://edx.devstack.lms:18000/ --catalog-api-url http://edx.devstack.discovery:18381/api/v1/ --theme-name edx.org'
echo 'copying discovery catalog'
docker compose exec -T credentials bash -c 'source /edx/app/credentials/credentials_env && python /edx/app/credentials/credentials/manage.py copy_catalog'
echo 'creating a program certificate configuration'
docker compose exec -T credentials bash -c 'source /edx/app/credentials/credentials_env && python /edx/app/credentials/credentials/manage.py create_program_certificate_configuration'

echo 'Updating LMS...'
echo 'creating a credentials API connection'
docker compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms create_credentials_api_configuration'
echo 'changing edX user enrollment in demo course from audit to verified'
docker compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms change_enrollment -u edx -c course-v1:edX+DemoX+Demo_Course --from audit --to verified'
echo 'manually ID verifying edX user'
docker compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms manual_verifications --email edx@example.com'
echo 'generating course certificate'
docker compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms cert_generation -u 3 -c course-v1:edX+DemoX+Demo_Course'
echo 'notifying credentials'
docker compose exec -T lms bash -c 'source /edx/app/edxapp/edxapp_env && python /edx/app/edxapp/edx-platform/manage.py lms --settings=devstack_docker notify_credentials --courses course-v1:edX+DemoX+Demo_Course --notify_programs'
