#include <stdio.h>
#include <stdlib.h>
#include <string.h>   
#include <strings.h>  
#include <unistd.h>   
#include <netdb.h>    
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

void error(char *msg)
{
    perror(msg);
    exit(0);
}

int main(int argc, char *argv[])
{
    int sockfd, portno, n, fromlen;

    struct sockaddr_in serv_addr, from;
    struct hostent *server;

    char buffer[1024];
    if (argc < 3) {
       fprintf(stderr,"usage %s hostname port\n", argv[0]);
       exit(0);
    }
    portno = atoi(argv[2]);
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) 
        error("ERROR opening socket");
    server = gethostbyname(argv[1]);
    if (server == NULL) {
        fprintf(stderr,"ERROR, no such host\n");
        exit(0);
    }
    bzero((char *) &serv_addr, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    bcopy((char *)server->h_addr, 
         (char *)&serv_addr.sin_addr.s_addr,
         server->h_length);
    serv_addr.sin_port = htons(portno);
    //if (connect(sockfd,(struct sockaddr *)&serv_addr,sizeof(serv_addr)) < 0) 
    //    error("ERROR connecting");
    printf("Please enter the message: ");
    bzero(buffer,1024);
    fgets(buffer,1023,stdin);
    //n = write(sockfd,buffer,strlen(buffer));
    n = sendto(sockfd, buffer, 1024,0,(struct sockaddr *) &serv_addr,sizeof(serv_addr));
    if (n < 0) 
         error("ERROR writing to socket");
    bzero(buffer,1024);
    //n = read(sockfd,buffer,255);
    //
    fromlen = sizeof(struct sockaddr_in);
    n = recvfrom(sockfd,buffer,1024,0,(struct sockaddr *)&from,&fromlen);
    if (n < 0) 
         error("ERROR reading from socket");
    printf("%s\n",buffer);
    return 0;
}
