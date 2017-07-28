build_fresh:
	docker build --no-cache -t "gyao/data_science_docker" .

build_incr:
	docker build -t "gyao/data_science_docker" .

run:
	docker run -p 22022:22 -p 8020:8020 -p 50010:50010 -p 50020:50020 -p 50070:50070 -p 50075:50075 -p 9001:9001 -p 8030:8030 -p 8031:8031 -p 8032:8032 -p 8033:8033 -p 8040:8040 -p 8042:8042 -p 8088:8088 -p 8080:8080 -p 7077:7077 -p 8888:8888 -p 8081:8081 -p 18080:18080 -p 8787:8787 -v $PWD/working:/working -it gyao/data_science_docker
