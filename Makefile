install:
	pip install --upgrade pip &&\
		pip install -r requirements.txt

init:
	python3 -m venv venv && source ./venv/bin/activate
	pip3 install --upgrade pip wheel setuptools awscli
	pip3 install -r requirements.txt

init_linux:
	sudo apt-get install python3-pip python3-venv
	sudo python3 -m venv venv && . ./venv/bin/activate
	sudo pip3 install --upgrade pip wheel setuptools awscli
	sudo pip3 install -r requirements.txt

build-emr-notebook-cluster:
	python3 $(pwd)/development/emr_notebooks/setup.py

build-glue-factory:
	python3 setup.py sdist
	rm -rf ./gluefactory ./gluefactory.egg-info
	mkdir ./gluefactory
	mv ./dist ./gluefactory
	tar -xvf ./gluefactory/dist/gluefactory-0.1.tar.gz -C ./gluefactory
	cd ./gluefactory/gluefactory-0.1
	python3 -m src
	rm -rf ./gluefactory/gluefactory-0.1

build-dwp-wheel:
	rm -rf whltmp
	mkdir whltmp
	cp -r ./development/wheel-dev/* ./whltmp
	python2 setup.py bdist_wheel
	mv ./dist/dwp_module-0.1-py2-none-any.whl ./src/jobs/wheel/glue_dwp_data
	rm -rf ./build ./dwp_module.egg-info ./whltmp ./dist

build-zeppelin:
	sh -e development/zeppelin/setup.sh

deploy-glue:
	python3 -m src

deploy-infrastructure-onetimesetup:
	aws cloudformation deploy \
	--template-file ./infrastructure/cf_infra_setup.yml \
	--stack-name 'glue-logging-infra-setup' \
	--tags owner=insights cost-centre=data environment=development \
	--capabilities CAPABILITY_NAMED_IAM \
	--region eu-central-1

	aws cloudformation deploy \
	--template-file ./infrastructure/cf_monitoring_setup \
	--stack-name 'glue-monitor-infra-setup' \
	--tags owner=insights cost-centre=data environment=development \
	--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	--region eu-central-1

deploy-infrastructure-update:
	rm -rf ./cftmp
	mkdir ./cftmp
	cat ./infrastructure/params/cf_infra_setup_uat.json |\
	jq '. += [ {"ParameterKey":"VersionCommit","ParameterValue": "manual push" }]' \
	> ./cftmp/cf_infra_setup_uat.json

	aws s3 cp ./infrastructure/cf_infra_setup.yml \
	s3://7digital-glue-workflows-uat/infrastructure/cf_infra_setup.yml \
	--region eu-central-1

	aws cloudformation update-stack \
	--stack-name 'glue-logging-infra-setup' \
	--template-url https://7digital-glue-workflows-uat.s3.eu-central-1.amazonaws.com/infrastructure/cf_infra_setup.yml \
	--parameters file://cftmp/cf_infra_setup_uat.json \
	--capabilities CAPABILITY_NAMED_IAM  \
	--region eu-central-1

	rm -rf ./cftmp

deploy-monitoring-update:
	rm -rf ./cftmp
	mkdir ./cftmp
	cat ./infrastructure/params/cf_monitoring_uat.json |\
	jq '. += [ {"ParameterKey":"VersionCommit","ParameterValue": "manual push" }]' \
	> ./cftmp/cf_monitoring_uat.json

	aws s3 cp ./infrastructure/cf_monitoring_setup.yml \
	s3://7digital-glue-workflows-uat/infrastructure/cf_monitoring_setup.yml \
	--region eu-central-1

	aws cloudformation update-stack \
	--stack-name 'glue-logging-monitor-setup' \
	--template-url https://7digital-glue-workflows-uat.s3.eu-central-1.amazonaws.com/infrastructure/cf_monitoring_setup.yml \
	--parameters file://cftmp/cf_monitoring_uat.json \
	--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	--region eu-central-1

	rm -rf ./cftmp

.PHONY:
	init
	build-emr-notebook-cluster
	build-src-wheel
	build-wheel
	build-zeppelin
	deploy-glue
	deploy-infrastructure-setup
	deploy-infrastructure-update
	deploy-monitoring-update