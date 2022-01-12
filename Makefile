deploy:
	@sed -i ""  "s/BAIDU_URL_SUBMIT_TOKEN/$BAIDU_URL_SUBMIT_TOKEN/g" _config.yml
	@npm install && hexo clean && hexo  g && hexo d

build:
	npm install && hexo clean && hexo s