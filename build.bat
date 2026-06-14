@echo off
set JAVA_HOME=D:\Program Files\Java\jdk-17
set MAVEN_OPTS=-Dmaven.repo.local=D:\apache-maven-3.9.9\repository
"D:\apache-maven-3.9.9\bin\mvn.cmd" clean package -DskipTests -f D:\RuoYi\pom.xml
