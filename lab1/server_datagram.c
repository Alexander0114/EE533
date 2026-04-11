/* A simple server in the internet domain using TCP
   The port number is passed as an argument */
#include <stdio.h>
#include <sys/types.h> 
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <strings.h>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>

void error(char *msg)
{
    perror(msg);
    exit(1);
}

void dostuff(int sockfd)
{
     int n;
     char buffer[256];

     bzero(buffer,256);
     n = read(sockfd,buffer,255);
     if (n < 0) error("ERROR reading from socket");
     printf("Here is the message: %s\n",buffer);
     n = write(sockfd,"I got your message",18);
     if (n < 0) error("ERROR writing to socket");

}

int main(int argc, char *argv[])
{
     int sockfd, newsockfd, portno, clilen;
     char buffer[256];
     char buf[1024];
     struct sockaddr_in serv_addr, cli_addr, from;
     int n;
     int fromlen;
     if (argc < 2) {
         fprintf(stderr,"ERROR, no port provided\n");
         exit(1);
     }
     sockfd = socket(AF_INET, SOCK_DGRAM, 0);
     if (sockfd < 0) 
        error("ERROR opening socket");
     bzero((char *) &serv_addr, sizeof(serv_addr));
     portno = atoi(argv[1]);
     serv_addr.sin_family = AF_INET;
     serv_addr.sin_addr.s_addr = INADDR_ANY;
     serv_addr.sin_port = htons(portno);
     if (bind(sockfd, (struct sockaddr *) &serv_addr,
              sizeof(serv_addr)) < 0) 
              error("ERROR on binding");

     printf("Start listening...\n");
     //listen(sockfd,5);
     clilen = sizeof(cli_addr);

     fromlen = sizeof(struct sockaddr_in);
     while (1)
     {
         n = recvfrom(sockfd,buf,1024,0,(struct sockaddr *)&from,&fromlen);
	 printf("Here is the message: %s\n",buf);
         if (n < 0) error("recvfrom");
         n = sendto(sockfd,"Got your message",17,0,(struct sockaddr *) &from,fromlen);
         if (n < 0) error("sendto");
     }
} 


