run:
	hugo serve

build:
	hugo

publish: build
	tar cvzf public.tar.gz public/
	scp public.tar.gz website:/tmp/
	ssh website "tar xvzf /tmp/public.tar.gz -C /tmp/; rm -rf /var/www/htdocs/matiasaguirre.com/*; mv /tmp/public/* /var/www/htdocs/matiasaguirre.com/; rm -rf /tmp/public*"
