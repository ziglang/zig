extern int ipfrule_add(void);
extern int ipfrule_remove(void);

extern frentry_t *ipfrule_match_out_(fr_info_t *, u_32_t *);
extern frentry_t *ipf_rules_out_[1];

extern int ipfrule_add_out_(void);
extern int ipfrule_remove_out_(void);

extern frentry_t *ipfrule_match_in_(fr_info_t *, u_32_t *);
extern frentry_t *ipf_rules_in_[1];

extern int ipfrule_add_in_(void);
extern int ipfrule_remove_in_(void);