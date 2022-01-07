deploy:
	@npm install && hexo clean && hexo  g && hexo d

build:
	npm install && hexo s