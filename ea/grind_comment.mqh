//+------------------------------------------------------------------+
//| grind_comment.mqh — GRIND order comment constructor and parser   |
//| Contract for Spec B state reconstruction. Pure / unit-testable.    |
//+------------------------------------------------------------------+
#ifndef GRIND_COMMENT_MQH
#define GRIND_COMMENT_MQH

#define GRIND_COMMENT_MAX_LEN 31

//+------------------------------------------------------------------+
string GrindCommentBuild(const string slot,
                         const string side_letter,
                         const int layer_index,
                         const string role)
{
   string nn = StringFormat("L%02d", layer_index);
   string comment = "GRIND|" + slot + "|" + side_letter + "|" + nn + "|" + role;
   if(StringLen(comment) > GRIND_COMMENT_MAX_LEN) {
      Print("FATAL: GRIND comment exceeds ", GRIND_COMMENT_MAX_LEN, " chars: ", comment);
   }
   return comment;
}

//+------------------------------------------------------------------+
bool GrindCommentRoleMatches(const string role_field, const string expected_prefix)
{
   if(StringLen(role_field) < StringLen(expected_prefix))
      return false;
   return (StringSubstr(role_field, 0, StringLen(expected_prefix)) == expected_prefix);
}

//+------------------------------------------------------------------+
bool GrindCommentParse(const string comment,
                       string &slot_out,
                       string &side_out,
                       int &layer_index_out,
                       string &role_out)
{
   slot_out = "";
   side_out = "";
   layer_index_out = -1;
   role_out = "";

   string parts[];
   const int n = StringSplit(comment, '|', parts);
   if(n < 5)
      return false;
   if(parts[0] != "GRIND")
      return false;
   if(parts[2] != "L" && parts[2] != "S")
      return false;

   slot_out = parts[1];
   side_out = parts[2];

   string layer_token = parts[3];
   if(StringLen(layer_token) < 2 || StringSubstr(layer_token, 0, 1) != "L")
      return false;
   layer_index_out = (int)StringToInteger(StringSubstr(layer_token, 1));

   string role_field = parts[4];
   if(GrindCommentRoleMatches(role_field, "ENT"))
      role_out = "ENT";
   else if(GrindCommentRoleMatches(role_field, "EXT"))
      role_out = "EXT";
   else
      return false;

   return true;
}

//+------------------------------------------------------------------+
int GrindCommentLengthForLayer(const int layer_index,
                               const string slot,
                               const string side_letter,
                               const string role)
{
   return StringLen(GrindCommentBuild(slot, side_letter, layer_index, role));
}

#endif // GRIND_COMMENT_MQH
