IFACE := re0

build:
	@ hugo

run:
	@ hugo server \
		-D \
		--bind=0.0.0.0 \
		--baseUrl=http://`ifconfig ${IFACE} | grep "inet.*broadcast.*\.255" | awk '{ print $$2 }'`/

deploy:
	@ rsync -avz --progress . matiasaguirre.net:website

.PHONY: run build deploy
