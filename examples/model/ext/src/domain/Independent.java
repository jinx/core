package domain;

import java.util.Collection;
import java.util.ArrayList;
import java.util.HashSet;

public class Independent extends DomainObject
{
    /**
     * A string property.
     */
    private String name;

    /**
     * The people which reference this object.
     * <p>
     * This property exercises a heterogenous 1:M reference.
     * </p>
     */
    private Collection<Person> people;

    /**
     * The other independents.
     * <p>
     * This property exercises an unparameterized M:N independent reference.
     * </p>
     */
    private Collection others;

    public Independent()
    {
        people = new HashSet<Person>();
        others = new ArrayList();
    }

    /**
     * @return the name
     */
    public String getName()
    {
        return name;
    }

    /**
     * @param name the name to set
     */
    public void setName(String name)
    {
        this.name = name;
    }

    /**
     * @return the others
     */
    public Collection<Person> getPeople()
    {
        return people;
    }

    /**
     * @param others the others to set
     */
    public void setPeople(Collection<Person> people)
    {
        this.people = people;
    }

    /**
     * @return the others
     */
    public Collection getOthers()
    {
        return others;
    }

    /**
     * @param others the others to set
     */
    public void setOthers(Collection others)
    {
        this.others = others;
    }
}
