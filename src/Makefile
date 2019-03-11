IFACE := re0

build:
	@ hugo

run:
	@ hugo server

deploy:
	@ rsync -avz --progress . matiasaguirre.net:website

.PHONY: run build deploy
