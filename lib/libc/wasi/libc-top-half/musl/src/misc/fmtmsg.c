/* Public domain fmtmsg()
 * Written by Isaac Dunham, 2014
 */
#include <fmtmsg.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
#include <pthread.h>
#endif

/*
 * If lstr is the first part of bstr, check that the next char in bstr
 * is either \0 or :
 */
static int _strcolcmp(const char *lstr, const char *bstr)
{
	size_t i = 0;
	while (lstr[i] && bstr[i] && (bstr[i] == lstr[i])) i++;
	if ( lstr[i] || (bstr[i] && bstr[i] != ':')) return 1;
	return 0;
}

int fmtmsg(long classification, const char *label, int severity,
           const char *text, const char *action, const char *tag)
{
	int ret = 0, i, consolefd, verb = 0;
	char *errstring = MM_NULLSEV, *cmsg = getenv("MSGVERB");
	char *const msgs[] = {
		"label", "severity", "text", "action", "tag", NULL
	};
	int cs;

#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
#endif

	if (severity == MM_HALT) errstring = "HALT: ";
	else if (severity == MM_ERROR) errstring = "ERROR: ";
	else if (severity == MM_WARNING) errstring = "WARNING: ";
	else if (severity == MM_INFO) errstring = "INFO: ";

	if (classification & MM_CONSOLE) {
		consolefd = open("/dev/console", O_WRONLY);
		if (consolefd < 0) {
			ret = MM_NOCON;
		} else {
			if (dprintf(consolefd, "%s%s%s%s%s%s%s%s\n",
			            label?label:"", label?": ":"",
			            severity?errstring:"", text?text:"",
			            action?"\nTO FIX: ":"",
			            action?action:"", action?" ":"",
			            tag?tag:"" )<1)
				ret = MM_NOCON;
			close(consolefd);
		}
	}

	if (classification & MM_PRINT) {
		while (cmsg && cmsg[0]) {
			for(i=0; msgs[i]; i++) {
				if (!_strcolcmp(msgs[i], cmsg)) break;
			}
			if (msgs[i] == NULL) {
				//ignore MSGVERB-unrecognized component
				verb = 0xFF;
				break;
			} else {
				verb |= (1 << i);
				cmsg = strchr(cmsg, ':');
				if (cmsg) cmsg++;
			}
		}
		if (!verb) verb = 0xFF;
		if (dprintf(2, "%s%s%s%s%s%s%s%s\n",
		            (verb&1 && label) ? label : "",
		            (verb&1 && label) ? ": " : "",
		            (verb&2 && severity) ? errstring : "",
		            (verb&4 && text) ? text : "",
		            (verb&8 && action) ? "\nTO FIX: " : "",
		            (verb&8 && action) ? action : "",
		            (verb&8 && action) ? " " : "",
		            (verb&16 && tag) ? tag : "" ) < 1)
			ret |= MM_NOMSG;
	}
	if ((ret & (MM_NOCON|MM_NOMSG)) == (MM_NOCON|MM_NOMSG))
		ret = MM_NOTOK;

#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	pthread_setcancelstate(cs, 0);
#endif

	return ret;
}
